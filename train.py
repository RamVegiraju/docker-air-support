"""Train and evaluate a tiny online classifier with River."""

import json
import random
from importlib.metadata import version

from river import linear_model, metrics, preprocessing


def examples(count: int, seed: int):
    rng = random.Random(seed)
    for _ in range(count):
        x1 = rng.gauss(0, 1)
        x2 = rng.gauss(0, 1)
        yield {"x1": x1, "x2": x2}, int(x1 + x2 > 0)


def main():
    model = preprocessing.StandardScaler() | linear_model.LogisticRegression()
    for features, label in examples(400, seed=7):
        model.learn_one(features, label)

    accuracy = metrics.Accuracy()
    for features, label in examples(100, seed=8):
        accuracy.update(label, model.predict_one(features))

    print(
        json.dumps(
            {
                "library": "river",
                "version": version("river"),
                "train_examples": 400,
                "test_examples": 100,
                "test_accuracy": round(accuracy.get(), 3),
            }
        ),
        flush=True,
    )


if __name__ == "__main__":
    main()
