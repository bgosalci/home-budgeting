# Home Budgeting

This repository contains a simple monthly home budgeting app.

## Usage
Open `index.html` in a browser to track your income and expenses for each month. The app now uses 95% of your screen width to provide a wider workspace.

The app now starts with no pre-filled categories or incomes. Previously seeded "Salary" and "Vala" income examples have been removed, so you can build your budget entirely from scratch. The *Clear* button in the categories section removes all categories and incomes for the current month.

## File Structure
JavaScript files are located in `app/js` and stylesheets in `app/css`.

### Month Controls
You can now add a new budget month or switch between months using the inline controls in the header.

### Button Styles
Delete and edit buttons now mirror the shape of primary actions while using a distinct secondary color for clarity.

### Money In Editing
Income entries can now be edited. Use the new edit button next to each income to modify its name or amount.

### Budget Layout
The Overview charts have been removed. The Money Out – Categories table now appears alongside Money In on the budget screen for easier access.

### Transactions Layout
The transactions screen now shows the monthly transaction list next to the add transaction form in an 80/20 two-column layout (list left, form right). The former Expenditure per Category chart has been removed.

The transaction list now fills nearly the entire screen without overflowing and scrolls within its card, while the add transaction form retains its original size.

Prices in the monthly transaction list are now larger, bold, and include extra right padding alongside the delete button for improved readability.

### Description Prediction
As you type a transaction description, the app suggests a previously used description based on your past entries. A tooltip beneath the field shows the best match; press the space bar to accept the suggestion and the description will auto‑fill.

## Tests
Run `npm test` to verify the project is set up correctly.
