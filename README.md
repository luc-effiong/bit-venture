# **BitVenture – Decentralized Startup Funding Protocol**

### **Overview**

BitVenture is a **trustless venture capital protocol** built on Bitcoin’s **Stacks layer**, enabling startups to raise funds through milestone-based campaigns while investors retain **on-chain governance rights** via tokenized equity.

This system introduces a decentralized model for **venture funding**, **governance**, and **capital release**, all secured by Bitcoin.

---

## **System Overview**

BitVenture bridges entrepreneurs and investors through transparent, milestone-controlled capital allocation.

* **Startups** deploy funding campaigns defining goals, milestones, and timelines.
* **Investors** commit STX in exchange for proportional **equity tokens** representing ownership and voting power.
* **Milestones** govern staged fund releases; investors vote to approve each milestone before funds are disbursed.
* **Platform governance** and fees are fully on-chain, ensuring sustainability and security.

This structure eliminates intermediaries, ensuring **founders’ accountability** and **investor protection**.

---

## **Core Features**

| Category                | Description                                                                                           |
| ----------------------- | ----------------------------------------------------------------------------------------------------- |
| **Campaign Creation**   | Founders create funding campaigns with goals, descriptions, and milestones.                           |
| **Investment & Equity** | Investors contribute STX, receive proportional equity tokens, and track portfolio performance.        |
| **Milestone Voting**    | Each milestone undergoes a decentralized voting phase; only approved milestones trigger fund release. |
| **Governance & Fees**   | Platform fees, campaign closures, and emergency controls are governed by on-chain logic.              |
| **Investor Protection** | Funds are released progressively based on verified performance milestones.                            |
| **Transparency**        | All campaigns, votes, and fund flows are visible on-chain.                                            |

---

## **Contract Architecture**

The protocol is composed of a **single Clarity smart contract** responsible for all core logic, including campaign management, milestone governance, and platform administration.

### **Key Components**

#### **1. Campaign Lifecycle**

* **`create-campaign`** – Initializes a new startup campaign.
* **`invest-in-campaign`** – Allows investors to fund a campaign.
* **`close-campaign`** – Marks a campaign as completed after funding or deadline.

#### **2. Milestone Management**

* **`create-milestone`** – Defines deliverable checkpoints within campaigns.
* **`vote-on-milestone`** – Investors cast approval or rejection votes.
* **`complete-milestone`** – Executes fund release upon approval majority (>50%).

#### **3. Investor & Portfolio Tracking**

* **`campaign-investments`** – Tracks per-investor contributions, equity, and timestamps.
* **`investor-portfolios`** – Aggregates investor participation and performance metrics.

#### **4. Platform Controls**

* **`set-platform-fee`** – Adjusts protocol fee (max 10%).
* **`toggle-pause`** – Pauses all platform operations in emergencies.
* **`withdraw-platform-fees`** – Allows the owner to withdraw accumulated fees.
* **`emergency-close-campaign` / `force-milestone-completion`** – Administrative recovery functions.

---

## **Data Structures**

### **Core Maps**

| Map                    | Purpose                                                            |
| ---------------------- | ------------------------------------------------------------------ |
| `campaigns`            | Stores core metadata and funding state for each campaign.          |
| `campaign-investments` | Tracks individual investor positions per campaign.                 |
| `campaign-milestones`  | Defines milestone details, voting states, and release logic.       |
| `milestone-votes`      | Records per-investor votes for milestone governance.               |
| `investor-portfolios`  | Summarizes each investor’s overall performance metrics.            |
| `campaign-stats`       | Captures campaign-level statistics (investors, averages, updates). |

### **Global Variables**

* `total-campaigns` – Incremental campaign counter
* `platform-fee-percentage` – Platform revenue basis points (default: 2.5%)
* `paused` – Operational pause flag
* `total-platform-fees` – Accumulated protocol revenue

---

## **Error Codes**

| Code   | Description             |
| ------ | ----------------------- |
| `u100` | Owner-only action       |
| `u101` | Unauthorized caller     |
| `u102` | Campaign not found      |
| `u103` | Campaign ended          |
| `u104` | Insufficient funds      |
| `u105` | Invalid parameter       |
| `u106` | Milestone not found     |
| `u107` | Already voted           |
| `u108` | Voting period ended     |
| `u109` | Milestone not completed |

---

## **Optional: Data Flow Summary**

1. **Founder → Create Campaign**
   Deploys a campaign specifying funding goals, duration, and milestones.
2. **Investor → Invest**
   Transfers STX, receives equity tokens. Platform fee auto-deducted.
3. **Investor → Vote on Milestone**
   Votes weighted by equity holdings.
4. **Milestone → Approval Threshold (>50%)**
   If approved, milestone marked complete; funds released.
5. **Platform → Governance & Fee Withdrawal**
   Owner adjusts parameters, withdraws fees, or pauses protocol.

---

## **Security and Governance Considerations**

* **Immutable transparency:** All state stored on-chain, auditable by anyone.
* **Investor protection:** Funds are milestone-gated, reducing founder default risk.
* **Emergency controls:** The protocol owner can pause, close, or force finalize only in extraordinary conditions.
* **Fee control:** Fee adjustments capped at 10%, ensuring sustainable economics.

---

## **Deployment**

### **Environment Requirements**

* [Stacks Blockchain API](https://docs.stacks.co/)
* [Clarinet CLI](https://docs.hiro.so/clarinet)
* Testnet wallet with STX for deployment and interaction.

### **Example Commands**

```bash
# Check contract syntax
clarinet check

# Run unit tests
clarinet test

# Deploy to local environment
clarinet deploy

# Interact (example)
clarinet console
(contract-call? .bitventure create-campaign "AlphaTech" "Decentralized AI startup" u100000000 u500 u5)
```

---

## **License**

This project is released under the **MIT License**.
Use, modify, and distribute freely with attribution.

---

## **Acknowledgments**

BitVenture builds on the vision of **Bitcoin-native capital formation** enabled by **Stacks smart contracts**.
Special thanks to the open-source community advancing **trustless finance**, **Clarity development**, and **on-chain venture governance**.
