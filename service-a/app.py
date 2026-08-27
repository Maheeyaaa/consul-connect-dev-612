from flask import Flask
import requests

app = Flask(__name__)

@app.route("/")
def home():
    response = requests.get("http://service-b:5000")
    return f"Service A received: {response.text}"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

