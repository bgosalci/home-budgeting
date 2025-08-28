# Home Budgeting

This repository contains a simple monthly home budgeting app.

The web page title is now "Home Budgeting".

## Usage
Open `index.html` in a browser to track your income and expenses for each month. The app now uses 95% of your screen width to provide a wider workspace.

The app now starts with no pre-filled categories or incomes. Previously seeded "Salary" and "Vala" income examples have been removed, so you can build your budget entirely from scratch. The previous *Clear* button has been removed; delete categories individually or start a new month if you need a blank slate. Categories can be collapsed or expanded using the secondary-styled controls above the table.

## File Structure
JavaScript files are located in `app/js` and stylesheets in `app/css`.

### Month Controls
You can add a new budget month or switch between months using the inline controls in the header. New months start with a copy of the previous month's categories so each month's budget can evolve independently. The previous **Duplicate Prev** button has been removed, and the **Add Month** and **Open Month** controls now appear on a single line for quicker access.

### Action Icons
Edit and delete actions across the app now use circular icon buttons for a cleaner look.
The icons now adopt the secondary theme colour instead of blue for consistency.

### Themed Dialogs
Alerts, confirmations and information messages now appear in a styled pop‑up dialog that matches the app's theme. Any attempt to delete a record prompts for confirmation.

### Money In Editing
Income entries can now be edited. Use the new edit button next to each income to modify its name or amount.

### Negative Number Highlighting
All negative monetary values are shown in red so overspending and refunds stand out immediately. This includes entries in Money In, category tables, transactions and KPIs.
Money In entries now correctly highlight negative amounts.

### Budget Layout
The Overview charts have been removed. The Money Out – Categories table now appears alongside Money In on the budget screen for easier access.

### Transactions Layout
The transactions screen now shows the monthly transaction list next to the add transaction form in an 80/20 two-column layout (list left, form right). The former Expenditure per Category chart has been removed.

The transaction list now fills nearly the entire screen without overflowing and scrolls within its card, while the add transaction form retains its original size.

The Monthly Transactions header now displays the total value of all transactions for the month on the right.

You can search the monthly transaction list by description and filter it by category.

A **Delete All** icon button sits beside the jump-to-top/bottom control beneath the transaction list and removes every transaction in the selected month after confirmation.

A circular button with a double chevron icon sits beneath the transaction list to jump to the end. When you reach the bottom it switches to an upward chevron icon to return to the beginning.

The monthly transactions card now leaves a 20px gap from the bottom of the screen for clearer separation from the edge.
A small gap now separates the category selector from the Add button for clearer entry.

Each transaction row now begins with a row number. Prices are bold, match the standard font size, and sit to the left of the edit/delete icons with extra spacing for clearer separation.
Transaction rows highlight on mouse hover for improved readability.

### Analysis Tab
An **Analysis** tab is now available after the Transactions tab. It provides **Budget Spread** and **Monthly Spend** options (listed alphabetically) to explore your data. The tab now defaults to the **Budget Spread** displayed as a bar chart. Use the **Chart Style** selector to switch between available chart types for the chosen analysis.

Selecting a different month in the Analysis tab now shows both planned and actual spending for that specific month instead of always using the current month.
The Monthly Spend view can now be filtered by group using the Group selector, which defaults to showing all groups. A Category selector beneath it lets you drill down to a single category.

### Transaction Editing
Each monthly transaction entry includes an edit icon so existing records can be updated.

Transactions are grouped by calendar day, with each date shown as a header followed by that day's entries.
Each header also displays the number of transactions for that day (e.g., "5 transactions"), the day's total spend, and the running total for the month so far.

### Import & Export Data
Use the **Import** and **Export** buttons to move data in or out of the app. A pop‑up dialog lets you choose the dataset:

 - **Monthly Transactions** – select the budget month and JSON or CSV file. CSV files may omit the header row; if so, uncheck **File has header row** when mapping fields so the first line is imported. If the columns are in the order Date, Description, Category, Amount the import runs automatically; otherwise a pop‑up will let you map each expected field to a column (each dropdown includes a blank option for fields not present). During mapping you can also choose to invert amount signs for statements where money out is negative. If the Category field is left blank or unmapped, the app predicts a category based on the description. Dates must be in `dd/mm/yyyy` format and amounts may include a leading `£` or commas as thousand separators; these characters are removed on import. The mapping dialog is wider so checkbox options align with their labels.
- **Money Out – Categories** – exports or imports the current month's category list as JSON.
- **Prediction Map** – exports or imports the description learning map as JSON.
- **All Data** – full backup of every month, category and prediction map as JSON.

Imported items are merged into existing data where applicable.

### Real-time Category Totals
The Money Out – Categories table refreshes instantly when you add new transactions so actual and difference values are always up to date.

Each month keeps its own set of categories. Adding a new month copies the previous month's categories, letting you tweak budgets without affecting past months.

### Description Prediction
As you type a transaction description, the app looks up your past entries that are stored in your browser's local storage. Only unique descriptions are kept. A tooltip beneath the field now spans the full width and lists up to four matches. Use the up and down keys to highlight an option and press <kbd>Enter</kbd> or click to choose one; the description will auto‑fill.

### Description → Category Map
The auto‑learning map that predicts a category from a description now takes the amount into account. When the same description appears with different amounts, the app can learn separate categories for each amount, letting a single description belong to multiple categories.

### Add Transaction Shortcuts
The add transaction form now requires a date, description and amount before a transaction can be added. Pressing <kbd>Enter</kbd> in any field triggers the add action, and focus returns to the description field to speed up entry of multiple transactions.

### Calendar
A **Calendar** tab opens a wide view-only calendar in a pop‑up dialog for quick date reference. The calendar shows the current month name, centers all weekday labels and dates, highlights today's date in bold, starts weeks on Monday, includes arrows to navigate between months, and shows each day's total transaction amount in the bottom-right corner of its cell using a secondary font color.

### Notes
The **Notes** tab opens a pop‑up dialog listing all saved notes. Each entry displays its description, note text and the time it was added, with edit and delete icon buttons for changes. Notes are stored in your browser's local storage so they are available across all months.

## Tests
Run `npm test` to verify the project is set up correctly.
