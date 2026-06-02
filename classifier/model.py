import logging
import numpy as np
import pandas as pd
from sklearn.pipeline import Pipeline, FeatureUnion
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import cross_val_score, StratifiedKFold
from sklearn.base import BaseEstimator, TransformerMixin

logger = logging.getLogger(__name__)


class ColumnSelector(BaseEstimator, TransformerMixin):
    """Extract a single column from a DataFrame."""

    def __init__(self, column: str):
        self.column = column

    def fit(self, X, y=None):
        return self

    def transform(self, X):
        return X[self.column]


class NumericSelector(BaseEstimator, TransformerMixin):
    """Extract and prepare numeric columns."""

    def __init__(self, column: str):
        self.column = column

    def fit(self, X, y=None):
        return self

    def transform(self, X):
        return X[[self.column]].fillna(0).values


def build_pipeline(
    min_df: int = 2,
    max_df: float = 0.95,
    tfidf_ngram: int = 2,
    c_param: float = 5.0,
    amount_weight: float = 0.1,
) -> Pipeline:
    """Build the sklearn pipeline with tunable hyperparameters."""
    text_pipe = Pipeline(
        [
            ("select_text", ColumnSelector("description")),
            (
                "tfidf",
                TfidfVectorizer(
                    analyzer="word",
                    ngram_range=(1, tfidf_ngram),
                    min_df=min_df,
                    max_df=max_df,
                    sublinear_tf=True,
                ),
            ),
        ]
    )

    numeric_pipe = Pipeline(
        [
            ("select_amount", NumericSelector("local_amount")),
            ("scaler", StandardScaler()),
        ]
    )

    features = FeatureUnion(
        [
            ("text", text_pipe),
            ("amount", numeric_pipe),
        ],
        transformer_weights={
            "text": 1.0,
            "amount": amount_weight,
        },
    )

    return Pipeline(
        [
            ("features", features),
            (
                "clf",
                LogisticRegression(
                    max_iter=1000,
                    C=c_param,
                    solver="lbfgs",
                ),
            ),
        ]
    )


def train(
    df: pd.DataFrame, verbose: bool = True, target_cv_accuracy: float = 0.77
) -> Pipeline:
    """
    Train the classifier iteratively until cross-validation reaches target_cv_accuracy.

    Iteratively adjusts hyperparameters to improve model performance.
    Excludes categories with only 1 member to avoid cross-validation issues.

    Args:
      df                    - DataFrame with columns: description, local_amount, category
      verbose               - if True, print cross-val scores and iterations with timestamps
      target_cv_accuracy    - target cross-validation accuracy to achieve (default 0.77)

    Returns fitted pipeline that meets target accuracy or best attempt after max iterations.
    """
    df = df.dropna(subset=["description", "local_amount", "category"])
    df = df.copy()
    df["description"] = df["description"].fillna("").str.lower().str.strip()
    df["local_amount"] = pd.to_numeric(df["local_amount"], errors="coerce").fillna(0)

    if len(df) == 0:
        raise ValueError("No valid training data after dropping nulls")

    # Remove categories with only 1 member to avoid cross-validation issues
    class_counts = df["category"].value_counts()
    single_member_classes = class_counts[class_counts == 1].index.tolist()
    if single_member_classes:
        if verbose:
            logger.info(
                f"Removing {len(single_member_classes)} single-member classes..."
            )
        df = df[~df["category"].isin(single_member_classes)]

    if len(df) == 0:
        raise ValueError("No training data after removing single-member categories")

    # Hyperparameter search space
    search_space = [
        # (min_df, max_df, tfidf_ngram, c_param, amount_weight, description)
        (2, 0.95, 2, 5.0, 0.1, "baseline"),
        (1, 0.95, 2, 5.0, 0.1, "lower min_df to 1"),
        (2, 0.95, 3, 5.0, 0.1, "increase ngram to 3"),
        (1, 0.90, 2, 5.0, 0.1, "lower min_df + max_df"),
        (1, 0.95, 3, 5.0, 0.1, "lower min_df + ngram=3"),
        (2, 0.95, 2, 10.0, 0.1, "increase C to 10"),
        (1, 0.95, 2, 10.0, 0.1, "lower min_df + C=10"),
        (2, 0.95, 2, 0.5, 0.1, "decrease C to 0.5"),
        (1, 0.90, 3, 5.0, 0.1, "lower min_df + max_df + ngram=3"),
        (1, 0.95, 2, 1.0, 0.1, "lower min_df + C=1"),
        (2, 0.95, 2, 5.0, 0.2, "increase amount_weight to 0.2"),
        (1, 0.90, 2, 10.0, 0.1, "aggressive: min_df=1, C=10"),
    ]

    best_score = 0.0
    best_pipe = None
    best_params = None

    cv = StratifiedKFold(n_splits=min(5, len(df) // 2), shuffle=True, random_state=42)

    if verbose:
        logger.info(
            f"Iteratively improving model to reach {target_cv_accuracy:.2f} CV accuracy..."
        )
        logger.info(
            f"Training data: {len(df)} rows, {df['category'].nunique()} categories"
        )

    for iteration, (min_df, max_df, ngram, c_param, amount_weight, desc) in enumerate(
        search_space, 1
    ):
        try:
            pipe = build_pipeline(
                min_df=min_df,
                max_df=max_df,
                tfidf_ngram=ngram,
                c_param=c_param,
                amount_weight=amount_weight,
            )

            scores = cross_val_score(
                pipe, df, df["category"], cv=cv, scoring="accuracy"
            )
            mean_score = scores.mean()

            if verbose:
                status = "✓" if mean_score >= target_cv_accuracy else " "
                pct = int((iteration / len(search_space)) * 100)
                progress = "▓" * (pct // 5) + "░" * ((100 - pct) // 5)
                logger.info(
                    f"[{progress:20s}] {status} {iteration:2d}/{len(search_space)}: {mean_score:.3f} ± {scores.std():.3f}  ({desc})"
                )

            if mean_score > best_score:
                best_score = mean_score
                best_params = (min_df, max_df, ngram, c_param, amount_weight, desc)
                best_pipe = pipe

            # Stop early if we reach target
            if mean_score >= target_cv_accuracy:
                if verbose:
                    logger.info(
                        f"✓ Target CV accuracy {target_cv_accuracy:.2f} achieved!"
                    )
                    logger.info(f"Final score: {mean_score:.3f} ± {scores.std():.3f}")
                    logger.info(f"Configuration: {desc}")
                    logger.info(
                        f"  min_df={min_df}, max_df={max_df}, ngram={ngram}, C={c_param}, amount_weight={amount_weight}"
                    )

                pipe.fit(df, df["category"])
                return pipe

        except Exception as e:
            if verbose:
                logger.warning(f"Iteration {iteration:2d}: Failed - {e}")
            continue

    # If we didn't reach target, use the best we found
    if verbose:
        logger.warning(f"Could not reach target CV accuracy {target_cv_accuracy:.2f}")
        logger.warning(f"Best achieved: {best_score:.3f}")
        logger.warning(f"Configuration: {best_params[-1] if best_params else 'none'}")
        if best_params:
            min_df, max_df, ngram, c_param, amount_weight, _ = best_params
            logger.warning(
                f"  min_df={min_df}, max_df={max_df}, ngram={ngram}, C={c_param}, amount_weight={amount_weight}"
            )

    if best_pipe is None:
        # Fallback to baseline if everything failed
        best_pipe = build_pipeline()

    best_pipe.fit(df, df["category"])
    return best_pipe


def predict_with_confidence(pipe: Pipeline, df: pd.DataFrame) -> pd.DataFrame:
    """
    Make predictions with confidence scores.

    Args:
      pipe - fitted pipeline
      df   - DataFrame with columns: description, local_amount

    Returns DataFrame with columns: [original columns] + predicted_category + confidence
    """
    df = df.copy()
    df["description"] = df["description"].fillna("").str.lower().str.strip()
    df["local_amount"] = pd.to_numeric(df["local_amount"], errors="coerce").fillna(0)

    proba = pipe.predict_proba(df)
    max_proba = np.max(proba, axis=1)
    predicted_labels = pipe.classes_[np.argmax(proba, axis=1)]

    df["predicted_category"] = predicted_labels
    df["confidence"] = max_proba

    return df
