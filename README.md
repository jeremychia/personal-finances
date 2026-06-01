# Personal Finance Data Pipeline

A comprehensive dbt (data build tool) project designed to manage, transform, and analyze personal financial data across multiple currencies, countries, and financial institutions. This project creates a unified data warehouse for tracking expenses, investments, and balances with proper foreign exchange handling and categorization.

## 🎯 Project Purpose

This dbt project consolidates financial data from various sources to provide:
- **Multi-currency financial tracking** with automatic SGD conversion
- **Investment portfolio monitoring** with gain/loss calculations
- **Expense categorization** and analysis across different spending patterns
- **Balance tracking** across bank accounts, credit cards, and investment platforms
- **Time-series analysis** with proper date dimensions

## 🏗️ Architecture Overview

The project follows a layered data architecture:

```
Sources → Staging → Facts/Dimensions → Marts
```

### Data Sources
- **Bank Transactions**: Multiple accounts across Singapore, Germany, France, Hong Kong, UK, and US
- **Investment Data**: Portfolio balances from various investment platforms
- **Foreign Exchange**: EUR and other currency exchange rates
- **Categories**: Manual categorization of transactions

### Key Features
- **Multi-currency support**: Primary focus on SGD with EUR, USD, HKD conversions
- **Temporal tracking**: Daily snapshots with historical analysis
- **Investment analytics**: Market value vs. cost basis with P&L calculations
- **Flexible categorization**: Hierarchical expense categories (category → category2 → category3)

## 📊 Data Model Structure

### Staging Layer (`models/staging/`)
Raw data transformation and standardization:
- **Bank staging**: Normalizes transaction data from 20+ bank/card sources
- **Investment staging**: Processes portfolio data from multiple investment platforms
- **FX staging**: Standardizes exchange rate data

### Facts Layer (`models/facts/`)
Core business events and metrics:
- `fact_bank_transactions`: All normalized bank transactions
- `fact_invm_balances_line_items`: Investment portfolio positions
- `fact_sgd_exchange_rates_long`: Daily FX rates in long format

### Dimensions Layer (`models/dimensions/`)
Reference data and categorization:
- `dim_categories`: Hierarchical expense categorization
- `dim_dates`: Date dimension with Singapore timezone

### Marts Layer (`models/marts/`)
Business-ready analytics tables:
- `mart_transactions`: Unified transaction view with SGD conversion
- `mart_sgd_balances`: Consolidated balance view (cash + investments)
- `mart_sgd_bank_transactions`: Bank transactions with category enrichment
- `mart_sgd_invm_balances`: Investment balances with P&L calculations

## 💰 Supported Financial Institutions

### Singapore
- **Banks**: DBS, UOB, OCBC, HSBC
- **Credit Cards**: Citi, Standard Chartered, UOB, HSBC
- **Digital**: Revolut, Wise

### International
- **Germany**: N26, AMEX (Payback, Rose Gold, Miles & More)
- **France**: HSBC France
- **Hong Kong**: Hang Seng Bank
- **UK/US**: Wise multi-currency accounts

### Investment Platforms
- Local SGD investments
- USD-denominated investments
- HKD/USD hybrid investments
- CDP (Central Depository) accounts
- FundingSocieties P2P lending

## 🌍 Currency Handling

The project handles multi-currency scenarios with:
- **Base currency**: Singapore Dollar (SGD) as the primary reporting currency
- **FX conversion**: Automated daily exchange rate application
- **FX gain/loss tracking**: Separate calculation of currency vs. investment gains
- **Timezone**: Asia/Singapore for consistent date handling

## 📈 Key Metrics & Analytics

### Transaction Analysis
- Spending by category with hierarchical breakdowns
- Fixed vs. variable expense classification
- Monthly/quarterly spending trends
- Cross-currency transaction analysis

### Investment Tracking
- Portfolio value vs. cost basis
- Investment gain/loss by currency
- FX gain/loss separate from investment performance
- Redemption tracking for realized gains

### Balance Monitoring
- Daily balance snapshots across all accounts
- Asset allocation across cash, credit, and investments
- Net worth calculation in SGD equivalent

## 🔧 Technical Implementation

### dbt Packages Used
- `dbt-utils`: For union operations and utility macros
- `dbt-date`: Singapore timezone handling and date operations
- `dbt-external-tables`: For external data source management

### Materialization Strategy
- **Staging models**: Views for flexibility and cost optimization
- **Facts/Marts**: Tables for performance on analytical queries
- **Documentation**: Comprehensive model and column documentation

### Data Quality
- Unique constraints on dimension keys
- Date validation and parsing
- Currency code standardization
- Category mapping validation

## 🚀 Getting Started

### Prerequisites
- Python 3.12 (or 3.10-3.13)
- Poetry for dependency management
- [direnv](https://direnv.net/) for automatic environment loading
- BigQuery project with appropriate permissions
- Google Cloud service account key

### Initial Setup

1. **Install direnv (if not already installed):**
   ```bash
   # macOS
   brew install direnv

   # Add to ~/.zshrc (or ~/.bashrc for bash)
   eval "$(direnv hook zsh)"

   # Restart your shell or run:
   source ~/.zshrc
   ```

2. **Install Python dependencies:**
   ```bash
   poetry install
   ```

3. **Configure BigQuery credentials:**

   Place your service account key in the `keys/` directory:
   ```bash
   # Option 1: Copy your key file
   cp /path/to/your-service-account-key.json keys/keyfile.json

   # Option 2: Create a symlink
   ln -s /path/to/your-service-account-key.json keys/keyfile.json
   ```

4. **Allow direnv for this project:**
   ```bash
   # From the project directory
   direnv allow
   ```

   Now the poetry environment and dbt variables load automatically when you cd into the project!

5. **Update profiles.yml:**

   Edit `dbt/profiles.yml` and update the `project` and `dataset` values:
   ```yaml
   jeremy-chia:
     outputs:
       dev:
         project: your-project-id  # Update this
         dataset: analytics_dev     # Update this
   ```

6. **Install dbt packages:**
   ```bash
   cd dbt
   dbt deps
   ```

7. **Install pre-commit hooks:**
   ```bash
   cd ..  # Back to project root
   pre-commit install
   ```

8. **Load seed data:**
   ```bash
   cd dbt
   dbt seed
   ```

9. **Build the project:**
   ```bash
   cd dbt
   # Dev environment (default)
   dbt build

   # Production environment
   dbt build --target prod
   ```

**Note:** With direnv, you don't need to prefix commands with `poetry run` - the virtual environment is automatically activated when you're in the project directory!

### Project Structure
The project is organized as follows:
- **`dbt/`** - All dbt files (models, seeds, macros, tests, etc.)
- **`classifier/`** - Placeholder for future classification pipeline
- **`keys/`** - BigQuery service account credentials (git-ignored)
- **`scripts/`** - Utility scripts
- **`pyproject.toml`** - Shared Python dependencies (root level)

### Customizing direnv Settings

To override environment variables locally (e.g., use prod by default):

```bash
# Create .envrc.local (git-ignored)
echo 'export DBT_TARGET=prod' > .envrc.local
direnv allow
```

## � Documentation Deployment

This project automatically deploys dbt documentation to GitHub Pages. The documentation includes:
- **Lineage graphs**: Visual representation of data flow and model dependencies
- **Model documentation**: Detailed descriptions of all models, columns, and tests
- **Source documentation**: Information about raw data sources and their schemas

### Accessing the Documentation
The dbt docs are automatically deployed to: `https://jeremychia.github.io/personal-finances/` (update this URL if you rename the repository)

### How it Works
The deployment is handled by a GitHub Actions workflow (`.github/workflows/deploy-dbt-docs.yml`) that:

1. **Triggers on**:
   - Push to the `main` branch
   - Pull requests to `main` (builds but doesn't deploy)
   - Manual workflow dispatch

2. **Build Process**:
   - Sets up Python 3.12 environment
   - Installs dependencies via Poetry
   - Authenticates with BigQuery using service account
   - Installs dbt packages
   - Generates dbt documentation (`dbt docs generate`)
   - Prepares files for GitHub Pages deployment

3. **Deployment**: Deploys the generated documentation to GitHub Pages (main branch only)

### Setup Requirements

To enable this workflow, you need to:

1. **Enable GitHub Pages** in your repository settings:
   - Go to Settings → Pages
   - Source: "GitHub Actions"

2. **Add BigQuery Service Account Secret**:
   ```bash
   # Create base64 encoded service account key
   cat keys/keyfile.json | base64 > keyfile_base64.txt
   ```
   - Go to Settings → Secrets and variables → Actions
   - Add repository secret named `DBT_SERVICE_ACCOUNT_KEY`
   - Paste the base64 encoded content as the value

3. **Repository Permissions**: Ensure the repository has the following permissions:
   - Contents: Read
   - Pages: Write
   - id-token: Write

### Manual Documentation Generation
To generate docs locally:
```bash
# Generate and serve documentation locally
dbt docs generate --target prod
dbt docs serve --port 8080
```

## �🔧 Development Setup

### Pre-commit Hooks
This project uses pre-commit hooks to maintain code quality:

```bash
# Install pre-commit hooks
pre-commit install

# Run hooks manually on all files
pre-commit run --all-files

# Run hooks on staged files (happens automatically on commit)
git commit -m "your message"
```

**Configured hooks:**
- SQL formatting with sqlfmt
- YAML formatting and validation
- dbt parse and compile checks
- Model documentation validation (marts/facts/dimensions only)
- Trailing whitespace and file ending fixes
- Secret detection
- Python code formatting with black

**Note**: Some hooks (like `check-model-has-description`) are intentionally scoped to specific layers to allow flexibility in staging models while enforcing standards on production models.

## 📝 Usage Examples

```sql
-- Monthly spending by category
select
    format_date('%Y-%m', local_date) as month, category2, sum(sgd_amount) as total_sgd
from mart_sgd_bank_transactions
where category3 = 'Expense'
group by 1, 2
order by 1 desc, 3 desc
;

-- Investment performance summary
select
    source,
    max(sgd_market) as current_value_sgd,
    max(sgd_invm_gain_loss) as investment_gain_loss,
    max(sgd_fx_gain_loss) as fx_gain_loss
from mart_sgd_invm_balances
where is_latest_date = true
group by 1
;

-- Net worth tracking
select local_date, sum(sgd_balance) as total_net_worth_sgd
from mart_sgd_balances
group by 1
order by 1
;

```

## 🛠️ Development

### Claude Code Integration

This project includes a custom Claude Code skill for consistent dbt model documentation.

**Invoke the skill:**
```
/dbt-docs
```

This provides documentation templates, examples, and a validation checklist when adding or updating dbt models.

**Learn the standard:** See `DOCUMENTATION_FRAMEWORK.md` for the design principles, information theory, and why this standard matters for financial consolidation systems.

This project provides a robust foundation for personal financial analysis with the flexibility to accommodate complex multi-currency scenarios and diverse financial institution integrations.
