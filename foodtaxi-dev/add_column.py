import mysql.connector

# Connect to the database
db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="",
    database="foodweb_db"
)

cursor = db.cursor()

# Add the email_status column to the accounts table
try:
    cursor.execute('ALTER TABLE accounts ADD COLUMN email_status ENUM("unverified", "verified") DEFAULT "unverified" AFTER user_type')
    db.commit()
    print('Email status column added successfully')
except mysql.connector.Error as err:
    print(f"Error: {err}")

cursor.close()
db.close()
