
IF DB_ID('ExpenseTracker') IS NULL
BEGIN
    CREATE DATABASE ExpenseTracker;
END;
GO
USE ExpenseTracker;
GO
CREATE TABLE dbo.Users (
    user_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    email NVARCHAR(150) UNIQUE NOT NULL,
    created_at DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.Categories (
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    category_name NVARCHAR(100) NOT NULL,
    keywords NVARCHAR(500) NULL -- optional keywords for auto-categorization
);
GO

-- Payment Methods
CREATE TABLE dbo.PaymentMethods (
    paymentmethod_id INT IDENTITY(1,1) PRIMARY KEY,
    method_name NVARCHAR(100) NOT NULL
);
GO

-- Expenses
CREATE TABLE dbo.Expenses (
    expense_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL FOREIGN KEY REFERENCES dbo.Users(user_id),
    category_id INT NULL FOREIGN KEY REFERENCES dbo.Categories(category_id),
    paymentmethod_id INT NULL FOREIGN KEY REFERENCES dbo.PaymentMethods(paymentmethod_id),
    amount DECIMAL(12,2) NOT NULL CHECK (amount >= 0),
    expense_date DATE NOT NULL,
    description NVARCHAR(1000) NULL,
    auto_categorized BIT DEFAULT 0, -- set to 1 when trigger assigns category
    created_at DATETIME DEFAULT GETDATE()
);
GO

-- 3) Sample Data
INSERT INTO dbo.Users (name, email) VALUES
('Aarav Mehta','aarav@example.com'),
('Priya Sharma','priya@example.com'),
('Ravi Nair','ravi@example.com');
GO

INSERT INTO dbo.Categories (category_name, keywords) VALUES
('Food','restaurant,coffee,lunch,dinner,burger,meal'),
('Transport','uber,ola,taxi,metro,bus,train,fuel,petrol'),
('Groceries','supermarket,grocery,store,vegetables,fruits'),
('Entertainment','movie,netflix,concert,play,cinema'),
('Bills','electricity,water,internet,phone,subscription'),
('Health','pharmacy,doctor,hospital,clinic,medicine'),
('Others','misc,other');
GO

INSERT INTO dbo.PaymentMethods (method_name) VALUES
('Cash'),('Credit Card'),('Debit Card'),('UPI'),('Net Banking');
GO

INSERT INTO dbo.Expenses (user_id, category_id, paymentmethod_id, amount, expense_date, description) VALUES
-- Some categorized expenses
(1,1,2,450.00,'2024-09-15','Dinner with friends at Olive Garden'),
(1,2,1,120.00,'2024-09-16','Uber to office'),
(2,3,4,980.50,'2024-09-17','Weekly groceries at SuperMart'),
(3,5,2,2300.00,'2024-09-18','Electricity bill for September'),
-- Some uncategorized to test auto-categorization
(1,NULL,4,60.00,'2024-09-19','Coffee at cafe'),
(2,NULL,1,300.00,'2024-09-20','Petrol refill'),
(3,NULL,5,150.00,'2024-09-21','Movie tickets'),
(1,NULL,3,50.00,'2024-09-22','Pharmacy purchase');
GO

-- 4) View: Monthly totals per user using window functions
CREATE VIEW dbo.vMonthlyUserTotals AS
SELECT 
    u.user_id,
    u.name,
    YEAR(e.expense_date) AS yr,
    MONTH(e.expense_date) AS mon,
    SUM(e.amount) AS total_spent,
    ROW_NUMBER() OVER (PARTITION BY u.user_id ORDER BY YEAR(e.expense_date) DESC, MONTH(e.expense_date) DESC) AS rn
FROM dbo.Expenses e
JOIN dbo.Users u ON e.user_id = u.user_id
GROUP BY u.user_id, u.name, YEAR(e.expense_date), MONTH(e.expense_date);
GO

-- 5) Stored Procedure: Monthly summary for a given user
CREATE PROCEDURE dbo.usp_GetMonthlySummary
    @UserID INT,
    @Year INT = NULL  -- if NULL, returns all years
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        YEAR(e.expense_date) AS Year,
        MONTH(e.expense_date) AS Month,
        c.category_name,
        SUM(e.amount) AS TotalAmount,
        COUNT(*) AS Transactions
    FROM dbo.Expenses e
    LEFT JOIN dbo.Categories c ON e.category_id = c.category_id
    WHERE e.user_id = @UserID
      AND (@Year IS NULL OR YEAR(e.expense_date) = @Year)
    GROUP BY YEAR(e.expense_date), MONTH(e.expense_date), c.category_name
    ORDER BY Year DESC, Month DESC, TotalAmount DESC;
END;
GO

-- 6) Trigger: Auto-categorize new expenses based on keywords in Categories.keywords
CREATE TRIGGER trg_AutoCategorizeExpenses
ON dbo.Expenses
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE e
    SET category_id = ISNULL(e.category_id, c.category_id),
        auto_categorized = CASE WHEN e.category_id IS NULL AND c.category_id IS NOT NULL THEN 1 ELSE e.auto_categorized END
    FROM dbo.Expenses e
    INNER JOIN inserted i ON e.expense_id = i.expense_id
    CROSS APPLY (
        SELECT TOP 1 category_id
        FROM dbo.Categories c2
        WHERE (
            EXISTS (
                SELECT 1 FROM STRING_SPLIT(c2.keywords, ',') k 
                WHERE CHARINDEX(LTRIM(RTRIM(k.value)), LOWER(ISNULL(i.description, ''))) > 0
            )
        )
        ORDER BY LEN(c2.keywords) DESC
    ) c;
END;
GO
IF OBJECT_ID('dbo.ExpenseAudit', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ExpenseAudit (
        audit_id INT IDENTITY(1,1) PRIMARY KEY,
        expense_id INT,
        action NVARCHAR(20),
        action_time DATETIME DEFAULT GETDATE(),
        details NVARCHAR(1000)
    );
END;
GO

CREATE TRIGGER trg_ExpenseAudit
ON dbo.Expenses
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.ExpenseAudit (expense_id, action, details)
        SELECT i.expense_id, 'INSERT', CONCAT('Created amount=', i.amount, '; desc=', i.description)
        FROM inserted i;
    END

    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.ExpenseAudit (expense_id, action, details)
        SELECT d.expense_id, 'DELETE_OR_UPDATE', CONCAT('Old amount=', d.amount, '; desc=', d.description)
        FROM deleted d;
    END
END;
GO

