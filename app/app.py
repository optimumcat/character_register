from database import *
from flask import Flask
from flask import request
import json

db = Database()

app = Flask(__name__)


@app.route('/add_character', methods=['POST'])
def add_character():
    # TODO: Add validation for the JSON
    data = json.loads(request.get_data())
    name = data['name']
    race = data['race']
    character_class = data['character_class']
    level = data['level']
    hp = data['hp']

    db.add_character(name, race, character_class, level, hp)

    return json.dumps(data), 201


@app.route('/healthcheck', methods=['GET'])
def healthcheck():
    return "OK", 200


@app.route('/initialize_database', methods=['POST'])
def initialize_database():
    # Should I be returning data like list_characters?
    return db.initialize_database(), 201


@app.route('/list_characters', methods=['GET'])
def list_characters():
    return db.print_table(), 200


if __name__ == '__main__':
    # app.run(debug=True)
    app.run(host="0.0.0.0")
