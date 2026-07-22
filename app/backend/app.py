import os
from bson import ObjectId
from flask import Flask, jsonify, request
from flask_cors import CORS
from pymongo import MongoClient, ASCENDING
from pymongo.errors import DuplicateKeyError, PyMongoError

app = Flask(__name__)
CORS(app)

MONGODB_URI = os.environ["MONGODB_URI"]
MONGODB_DB = os.getenv("MONGODB_DB", "user_registration")

client = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=8000)
db = client[MONGODB_DB]
users = db["users"]
users.create_index([("name", ASCENDING)])


def serialize_user(user):
    return {
        "id": str(user["_id"]),
        "name": user["name"],
        "city": user["city"],
        "degree": user["degree"],
    }


@app.get("/api/health")
def health():
    try:
        client.admin.command("ping")
        return jsonify({"status": "healthy", "database": "connected"}), 200
    except PyMongoError as exc:
        return jsonify({"status": "unhealthy", "error": str(exc)}), 503


@app.get("/api/users")
def get_users():
    search = request.args.get("search", "").strip()
    query = {}
    if search:
        query = {
            "$or": [
                {"name": {"$regex": search, "$options": "i"}},
                {"city": {"$regex": search, "$options": "i"}},
                {"degree": {"$regex": search, "$options": "i"}},
            ]
        }

    result = [serialize_user(user) for user in users.find(query).sort("_id", -1)]
    return jsonify(result), 200


@app.post("/api/users")
def create_user():
    payload = request.get_json(silent=True) or {}
    name = str(payload.get("name", "")).strip()
    city = str(payload.get("city", "")).strip()
    degree = str(payload.get("degree", "")).strip()

    if not name or not city or not degree:
        return jsonify({"error": "Name, city and degree are required."}), 400

    document = {"name": name, "city": city, "degree": degree}
    try:
        inserted = users.insert_one(document)
        document["_id"] = inserted.inserted_id
        return jsonify(serialize_user(document)), 201
    except DuplicateKeyError:
        return jsonify({"error": "This user already exists."}), 409
    except PyMongoError as exc:
        return jsonify({"error": str(exc)}), 500


@app.delete("/api/users/<user_id>")
def delete_user(user_id):
    try:
        result = users.delete_one({"_id": ObjectId(user_id)})
    except Exception:
        return jsonify({"error": "Invalid user ID."}), 400

    if result.deleted_count == 0:
        return jsonify({"error": "User not found."}), 404
    return jsonify({"message": "User deleted."}), 200


@app.errorhandler(404)
def not_found(_):
    return jsonify({"error": "Route not found."}), 404
