# Transaction Business Rules & Limits Specification

This document strictly defines the financial constraints, limits, and fee structures for all transactions within the application. Any transaction (whether entered manually or parsed via SMS overlay) MUST pass these rules before being committed to the database.

## 1. Core Logic & Balance Constraints
* **Positive Amount Rule:** The transaction amount for any operation (send, receive, deposit) MUST be strictly greater than zero (`amount > 0`).
* **Balance Sufficiency Rule:** A wallet CANNOT perform a 'send' transaction if its current balance is strictly less than the transaction amount (`balance < amount`). Negative balances are strictly forbidden.

## 2. Wallet Capacity Limits (By Status)
These limits apply based on the wallet's assigned status:
* **New Wallet ('new'):**
  * Maximum Single Transaction: 10,000 EGP
  * Monthly Limit: 60,000 EGP
* **Old Wallet ('old'):**
  * Maximum Single Transaction: 60,000 EGP
  * Monthly Limit: 200,000 EGP
* **Registered Store Wallet ('registered_store'):**
  * Maximum Single Transaction: 60,000 EGP
  * Monthly Limit: 400,000 EGP

## 3. Network & Type Specific Limits
These limits override or apply alongside the status limits depending on the wallet type:
* **InstaPay Wallets ('instapay'):**
  * Maximum Single Transaction: 70,000 EGP
  * Daily Limit: 120,000 EGP
  * Monthly Limit: 400,000 EGP
* **Telecom Wallets (Vodafone Cash, Orange Cash, Etisalat Cash, WE Pay):**
  * Maximum Single Transaction: 60,000 EGP

## 4. Commission and Fee Calculation Rules
* **InstaPay Universal Transfer:**
  * Transfer to ANY destination costs 0.1% of the total amount.
  * Minimum fee: 0.5 EGP.
  * Maximum fee cap: 20.0 EGP.
* **Telecom Inter-Network Transfers (Vodafone, Orange, Etisalat, WE):**
  * Note: WE Pay follows the exact same fee structure as Vodafone Cash.
  * Same Network Transfer (e.g., Vodafone to Vodafone): Flat fee of 1.0 EGP.
  * Cross-Network Transfer (e.g., Vodafone to Orange/InstaPay): Costs 0.5% of the total amount.
    * Minimum fee: 1.0 EGP.
    * Maximum fee cap: 15.0 EGP.