from __future__ import annotations

from flask import jsonify


def success(data=None, message="OK", status_code=200):
    return jsonify({"success": True, "message": message, "data": data}), status_code


def error(message="Xatolik yuz berdi", errors=None, status_code=400):
    return jsonify({"success": False, "message": message, "errors": errors}), status_code
