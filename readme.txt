Expense Tracker SQL Server Project
Generated: 2025-11-05T06:46:18.956381

Files:
- expense_tracker.sql    : Full SQL Server T-SQL script to create database, tables, sample data, views, stored procedures, triggers, and audit table.
- readme.txt             : This help file.

How to run:
1. Open SQL Server Management Studio (SSMS).
2. Open the file 'expense_tracker.sql' in a new query window.
3. Execute the script (press F5). The script will create the database 'ExpenseTracker' and all objects.
4. To test, run sample queries mentioned at the bottom of the SQL file, for example:
   EXEC dbo.usp_GetMonthlySummary @UserID = 1;

Notes:
- The auto-categorization trigger uses STRING_SPLIT (available in SQL Server 2016+) to split keywords.
- If your SQL Server instance requires different permissions, run as a user with CREATE DATABASE rights.
