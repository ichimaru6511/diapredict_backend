# Diabetes Prediction Backend

Flask API for the FYP "Mobile Application for Predicting Diabetes Using Machine
Learning Classification Techniques". Serves the selected Random Forest model.

## Files
- app.py                  Flask API (/health, /predict)
- diabetes_rf_model.pkl   Selected Random Forest model (copy from the notebook folder)
- feature_order.pkl       Feature order expected by the model (copy from the notebook folder)
- requirements.txt        Python packages (scikit-learn and NumPy pinned to the notebook versions)
- test_api.py             Local test script (not needed on Render)

## Run locally
    pip install -r requirements.txt
    python app.py
Then, in a second terminal:
    python test_api.py

## API
GET /health  -> {"status": "ok", "model_loaded": true, "features": [...]}

POST /predict (JSON body):
    {
      "FastingBloodSugar": 150,      (mg/dL, number)
      "HbA1c": 7.5,                  (%, number)
      "FrequentUrination": 1,        (0 = No, 1 = Yes)
      "Hypertension": 0,
      "ExcessiveThirst": 1,
      "UnexplainedWeightLoss": 0
    }
Response:
    {"probability": 87.5, "prediction": "Diabetes", "threshold": 0.5,
     "warnings": [], "disclaimer": "..."}

## Deploy on Render
- Build command: pip install -r requirements.txt
- Start command: gunicorn app:app
- Environment variable: PYTHON_VERSION = 3.13.9