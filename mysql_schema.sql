-- QuickApp - MySQL Schema Conversion
-- Convert the SQL Server schema to MySQL

CREATE DATABASE IF NOT EXISTS u337053559_QuickApp;
USE u337053559_QuickApp;

-- Users table
CREATE TABLE IF NOT EXISTS Users (
    UserId CHAR(36) NOT NULL PRIMARY KEY DEFAULT (UUID()),
    Email VARCHAR(255) NOT NULL UNIQUE,
    PhoneNumber VARCHAR(20) NULL UNIQUE,
    PasswordHash VARCHAR(500) NOT NULL,
    FirstName VARCHAR(100) NOT NULL,
    LastName VARCHAR(100) NOT NULL,
    UserType INT NOT NULL COMMENT '1:Customer, 2:Supplier, 3:Driver, 4:Admin',
    IsActive BIT NOT NULL DEFAULT 1,
    IsVerified BIT NOT NULL DEFAULT 0,
    CreatedDate DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    LastLoginDate DATETIME(6) NULL,
    ProfileImageUrl VARCHAR(500) NULL,
    PreferredLanguage VARCHAR(10) NOT NULL DEFAULT 'en'
);

-- Sample data for testing
INSERT INTO Users (UserId, Email, PhoneNumber, PasswordHash, FirstName, LastName, UserType, IsActive, IsVerified)
SELECT '550e8400-e29b-41d4-a716-446655440000', 'admin@quickapp.com', '+1234567890',
       '$2a$11$example.hash.here', 'Admin', 'User', 4, 1, 1
WHERE NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'admin@quickapp.com');

SELECT 'QuickApp MySQL database setup complete!' AS Status;