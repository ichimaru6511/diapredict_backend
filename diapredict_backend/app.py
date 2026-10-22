from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import pandas as pd

app = Flask(__name__)
CORS(app)  # allow the Flutter app to call this API

# load the saved model and the feature order (from the Jupyter notebook)
model = joblib.load("diabetes_rf_model.pkl")
feature_order = joblib.load("feature_order.pkl")

# numerical features and the range seen in the training data
NUMERIC_RANGES = {
    "FastingBloodSugar": (70, 200),   # mg/dL
    "HbA1c": (4.0, 10.0)              # %
}

# yes/no features (must be 0 or 1)
BINARY_FEATURES = [
    "FrequentUrination",
    "Hypertension",
    "ExcessiveThirst",
    "UnexplainedWeightLoss"
]

THRESHOLD = 0.5

DISCLAIMER = ("This result is a decision-support aid from a prototype machine "
              "learning model and has not been clinically validated. It is not a "
              "medical diagnosis and should be interpreted together with clinical "
              "judgement and confirmatory testing.")


@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "model_loaded": model is not None,
        "features": feature_order
    })


@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_json(silent=True)
    if data is None:
        return jsonify({"error": "Request body must be JSON."}), 400

    # 1. check that all six features are present
    missing = []
    for f in feature_order:
        if f not in data:
            missing.append(f)
    if len(missing) > 0:
        return jsonify({"error": "Missing fields", "missing": missing}), 400

    values = {}
    warnings = []

    # 2. check the numerical features
    for f in NUMERIC_RANGES:
        try:
            value = float(data[f])
        except (TypeError, ValueError):
            return jsonify({"error": f + " must be a number."}), 400
        if value <= 0:
            return jsonify({"error": f + " must be greater than 0."}), 400

        low, high = NUMERIC_RANGES[f]
        if value < low or value > high:
            warnings.append(f + " (" + str(value) + ") is outside the range used to "
                            "train the model (" + str(low) + "-" + str(high) + "). "
                            "The prediction may be less reliable.")
        values[f] = value

    # 3. check the yes/no features
    for f in BINARY_FEATURES:
        value = data[f]
        if value not in [0, 1]:
            return jsonify({"error": f + " must be 0 (No) or 1 (Yes)."}), 400
        values[f] = int(value)

    # 4. predict (columns in the exact order the model expects)
    row = pd.DataFrame([values])[feature_order]
    prob = float(model.predict_proba(row)[0, 1])

    if prob >= THRESHOLD:
        label = "Diabetes"
    else:
        label = "No Diabetes"

    return jsonify({
        "probability": round(prob * 100, 1),   # e.g. 87.5 (%)
        "prediction": label,
        "threshold": THRESHOLD,
        "warnings": warnings,
        "disclaimer": DISCLAIMER
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
