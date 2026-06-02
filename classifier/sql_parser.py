import re
import sqlglot
from sqlglot.expressions import Column


def extract_description_columns(sql_text: str) -> list[str]:
    """
    Extract column names that feed into the `description` alias from a dbt staging SQL file.

    Handles three patterns:
    - Pass-through: `description` (no transformation)
    - Single alias: `some_col as description`
    - Multi-column concat: `concat(col1, col2, col3, ...) as description`

    Returns a list of source column names (lowercased). Raises ValueError if extraction fails.
    """
    # Strip Jinja template expressions by replacing with a stub table name
    sql_clean = re.sub(r"\{\{[^}]*\}\}", "source_table", sql_text)

    try:
        parsed = sqlglot.parse_one(sql_clean, dialect="bigquery")
    except Exception as e:
        raise ValueError(f"Failed to parse SQL: {e}")

    # Find the SELECT statement that contains the `description` alias
    select_stmts = list(parsed.find_all(sqlglot.exp.Select))
    if not select_stmts:
        raise ValueError("No SELECT statement found in SQL")

    # Use the last SELECT (usually in the final CTE)
    select_stmt = select_stmts[-1]

    # Find the alias/expression for `description`
    description_expr = None
    for expr in select_stmt.expressions:
        # Check if the alias is "description"
        if (
            hasattr(expr, "alias")
            and expr.alias
            and expr.alias.lower() == "description"
        ):
            description_expr = expr.this
            break
        # Also check bare column named `description` (pass-through case)
        elif (
            isinstance(expr, sqlglot.exp.Column) and expr.name.lower() == "description"
        ):
            description_expr = expr
            break

    if description_expr is None:
        raise ValueError("No 'description' column or alias found in SELECT")

    # Extract all column names from the expression
    columns = set()
    for col_node in description_expr.find_all(Column):
        col_name = col_node.name.lower()
        # Skip if it's a known function name or special token (basic filter)
        if col_name not in ("", "null", "true", "false"):
            columns.add(col_name)

    if not columns:
        raise ValueError("No source columns found in description expression")

    return sorted(list(columns))


def get_description_expression(sql_text: str) -> str:
    """
    Extract the SQL expression that computes `description` from a staging SQL file.

    Returns the expression as a string (e.g., "trim(concat(...))")
    Raises ValueError if extraction fails.
    """
    # Strip Jinja template expressions
    sql_clean = re.sub(r"\{\{[^}]*\}\}", "source_table", sql_text)

    try:
        parsed = sqlglot.parse_one(sql_clean, dialect="bigquery")
    except Exception as e:
        raise ValueError(f"Failed to parse SQL: {e}")

    # Find the SELECT statement
    select_stmts = list(parsed.find_all(sqlglot.exp.Select))
    if not select_stmts:
        raise ValueError("No SELECT statement found in SQL")

    select_stmt = select_stmts[-1]

    # Find the description expression
    for expr in select_stmt.expressions:
        if (
            hasattr(expr, "alias")
            and expr.alias
            and expr.alias.lower() == "description"
        ):
            # Return the expression as SQL
            return expr.this.sql(dialect="bigquery")
        elif (
            isinstance(expr, sqlglot.exp.Column) and expr.name.lower() == "description"
        ):
            return expr.sql(dialect="bigquery")

    raise ValueError("No 'description' column or alias found in SELECT")


def evaluate_description_expression(sql_text: str, row_data: dict) -> str:
    """
    Evaluate the description expression using values from a row of data.

    Args:
        sql_text: The staging SQL file content
        row_data: Dictionary with column names as keys and values from the sheet

    Returns the computed description string (same as the staging model would compute)
    """
    # Get the description expression
    expr_sql = get_description_expression(sql_text)

    # Normalize column names to lowercase for matching
    row_data_lower = {k.lower(): v for k, v in row_data.items()}

    try:
        result = _simple_sql_eval(expr_sql, row_data_lower)
        return str(result) if result else ""
    except Exception:
        # Fallback: if evaluation fails, try to manually handle common patterns
        return _manual_expression_eval(expr_sql, row_data_lower)


def _simple_sql_eval(expr: str, context: dict) -> str:
    """Simple evaluation of common SQL functions."""
    # Create a normalized lookup for column values
    # Normalize both spaces and underscores to handle "Payment reference" vs "payment_reference"
    context_normalized = {}
    for k, v in context.items():
        # Normalize: lowercase, replace spaces with underscores
        normalized_key = k.lower().replace(" ", "_")
        context_normalized[normalized_key] = v

    # Replace column references with actual values
    for col_name_normalized, col_value in context_normalized.items():
        col_value_str = str(col_value) if col_value is not None else ""
        # Replace column name with quoted value (case-insensitive regex)
        # Match with either spaces or underscores: "payment_reference" or "payment reference"
        pattern = col_name_normalized.replace("_", "[_ ]")
        pattern = rf"\b{pattern}\b"
        expr = re.sub(pattern, f"'{col_value_str}'", expr, flags=re.IGNORECASE)

    # Handle CAST: CAST(...  AS STRING) -> just the inner part
    expr = re.sub(
        r"CAST\s*\(\s*('[^']*')\s*AS\s+STRING\s*\)", r"\1", expr, flags=re.IGNORECASE
    )

    # Handle COALESCE: coalesce('val1', 'val2') -> first non-empty, repeatedly
    max_iterations = 10
    while max_iterations > 0:
        new_expr = re.sub(
            r"COALESCE\s*\(\s*'([^']*)'\s*,\s*'([^']*)'\s*\)",
            lambda m: f"'{m.group(1) if m.group(1) else m.group(2)}'",
            expr,
            flags=re.IGNORECASE,
        )
        if new_expr == expr:
            break
        expr = new_expr
        max_iterations -= 1

    # Handle CONCAT: concat('a', 'b', 'c') -> 'abc', repeatedly
    max_iterations = 10
    while max_iterations > 0:
        new_expr = re.sub(
            r"CONCAT\s*\(\s*('[^']*'(?:\s*,\s*'[^']*')*)\s*\)",
            lambda m: "'" + "".join(re.findall(r"'([^']*)'", m.group(1))) + "'",
            expr,
            flags=re.IGNORECASE,
        )
        if new_expr == expr:
            break
        expr = new_expr
        max_iterations -= 1

    # Handle TRIM: trim('  value  ') -> 'value'
    expr = re.sub(
        r"TRIM\s*\(\s*('[^']*')\s*\)",
        lambda m: f"'{m.group(1)[1:-1].strip()}'",
        expr,
        flags=re.IGNORECASE,
    )

    # Extract final quoted value
    match = re.search(r"'([^']*)'", expr)
    return match.group(1) if match else ""


def _manual_expression_eval(expr: str, context: dict) -> str:
    """Fallback manual evaluation for SQL expressions."""
    try:
        # Very simple case: just column name
        expr_clean = expr.strip().lower()
        if expr_clean in context:
            return str(context[expr_clean]) if context[expr_clean] is not None else ""

        # Try simple evaluation
        result = _simple_sql_eval(expr, context)
        return result if result else ""
    except Exception:
        return ""
