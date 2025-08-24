# Home Budgeting

This repository contains a simple monthly home budgeting app.

## Usage
Open `index.html` in a browser to track your income and expenses for each month. The app now uses 95% of your screen width to provide a wider workspace.

The app now starts with no pre-filled categories or incomes. Previously seeded "Salary" and "Vala" income examples have been removed, so you can build your budget entirely from scratch. The previous *Clear* button has been removed; delete categories individually or start a new month if you need a blank slate. Categories can be collapsed or expanded using the secondary-styled controls above the table.

## File Structure
JavaScript files are located in `app/js` and stylesheets in `app/css`.

### Month Controls
You can now add a new budget month or switch between months using the inline controls in the header.

### Action Icons
Edit and delete actions across the app now use circular icon buttons for a cleaner look.

### Money In Editing
Income entries can now be edited. Use the new edit button next to each income to modify its name or amount.

### Budget Layout
The Overview charts have been removed. The Money Out – Categories table now appears alongside Money In on the budget screen for easier access.

### Transactions Layout
The transactions screen now shows the monthly transaction list next to the add transaction form in an 80/20 two-column layout (list left, form right). The former Expenditure per Category chart has been removed.

The transaction list now fills nearly the entire screen without overflowing and scrolls within its card, while the add transaction form retains its original size.

A small gap now separates the category selector from the Add button for clearer entry.

Prices in the monthly transaction list are now larger, bold, and include extra right padding alongside the delete button for improved readability.

### Transaction Editing
Each monthly transaction entry includes an edit icon so existing records can be updated.

Transactions are grouped by calendar day, with each date shown as a header followed by that day's entries.

### Real-time Category Totals
The Money Out – Categories table refreshes instantly when you add new transactions so actual and difference values are always up to date.

### Description Prediction
As you type a transaction description, the app looks up your past entries that are stored in your browser's local storage. Only unique descriptions are kept. A tooltip beneath the field shows the best match; press the space bar to accept the suggestion and the description will auto‑fill.

### Add Transaction Shortcuts
The add transaction form now requires a date, description and amount before a transaction can be added. Pressing <kbd>Enter</kbd> in any field triggers the add action, and focus returns to the description field to speed up entry of multiple transactions.

## Tests
Run `npm test` to verify the project is set up correctly.
