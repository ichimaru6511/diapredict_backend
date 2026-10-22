import requests

URL = "http://127.0.0.1:5000"

print("Health:", requests.get(URL + "/health").json())

patient = {
    "FastingBloodSugar": 150, "HbA1c": 7.5,
    "FrequentUrination": 1, "Hypertension": 0,
    "ExcessiveThirst": 1, "UnexplainedWeightLoss": 0
}
print("\nNormal input:", requests.post(URL + "/predict", json=patient).json())

patient_high = dict(patient, FastingBloodSugar=250)
print("\nOut of range:", requests.post(URL + "/predict", json=patient_high).json())

bad = dict(patient, Hypertension=2)
r = requests.post(URL + "/predict", json=bad)
print("\nInvalid input:", r.status_code, r.json())
