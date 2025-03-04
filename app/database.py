import mysql.connector
import os


class Database:
    def __init__(self):
        self.mydb = mysql.connector.connect(
            host=os.getenv("DB_ENDPOINT"),
            user=os.getenv("DB_USER"),
            # TODO: Replace with better secrets management
            password=os.getenv("DB_PASSWORD"),
            database="character_register"
        )

        self.mycursor = self.mydb.cursor()

        try:
            # TODO: Replace print statements with logging
            print("Initializing database...")
            self.initialize_database()
        except mysql.connector.ProgrammingError as e:
            print("Database already exists.")
            pass

    def initialize_database(self):
        query = '''
        CREATE TABLE characters (
            id int NOT NULL AUTO_INCREMENT,
            name VARCHAR(255),
            race VARCHAR(255),
            class VARCHAR(255),
            level INT,
            hp INT,
            PRIMARY KEY (id)
        )
        '''
        self.mycursor.execute(query)
        return self.mycursor.fetchall()

    def print_table(self):
        self.mycursor.execute("SELECT * FROM characters")
        return self.mycursor.fetchall()

    def add_character(self, name, race, character_class, level, hp):
        # TODO: Write class/function to build query
        self.mycursor.execute(f"INSERT INTO characters (name, race, class, level, hp) VALUES ('{name}', '{race}', '{character_class}', '{level}', {hp})")
