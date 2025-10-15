# GCP Budget Guardian: Automated Billing Disabler

This project uses Terraform to deploy a serverless automation on Google Cloud Platform (GCP) that automatically disables billing for a specific project when a budget threshold is reached.

It's an ideal "kill switch" for lab, development, or sandbox environments to prevent unexpected costs.

---

## How It Works

The architecture is designed to be safe and robust by using a two-project setup:

1.  **Management Project:** A stable, low-cost project that hosts the automation logic (Cloud Function, Pub/Sub topic, and Service Account).
2.  **Target Project:** The project being monitored. When its budget is exceeded, billing is disabled for this project.

**The automation flow is as follows:**
1.  A **Cloud Billing Budget** tracks the costs of the target project.
2.  When the cost exceeds the defined amount, a notification is sent to a **Pub/Sub topic**.
3.  The Pub/Sub message triggers a **Python Cloud Function**.
4.  The function uses a privileged Service Account to call the Cloud Billing API, **detaching the target project from its billing account** and stopping all further charges.

---

## Prerequisites


- [Terraform]
- [Google Cloud SDK (`gcloud`)]
- An active GCP Billing Account.

---

## How to Use

1.  **Clone the repository and navigate into the directory.**

2.  **Configure your variables:**
    Copy the example variables file:
    ```sh
    cp terraform.tfvars.example terraform.tfvars
    ```
    Then, edit `terraform.tfvars` with your specific project and billing account IDs.

3.  **Initialize Terraform:**
    This command downloads the necessary provider plugins.
    ```sh
    terraform init
    ```

4.  **Plan the deployment:**
    Review the resources that Terraform will create.
    ```sh
    terraform plan
    ```

5.  **Apply the configuration:**
    Deploy the infrastructure to GCP.
    ```sh
    terraform apply
    ```
    Enter `yes` when prompted to confirm.

---

## How to Test

To test the function without waiting for a real billing alert, you can manually publish a message to the Pub/Sub topic. Run the following command in your Cloud Shell, replacing the variables accordingly.

```sh
gcloud pubsub topics publish YOUR_TOPIC_NAME \
--message='{"budgetAmount": 10.0, "costAmount": 12.5, "currencyCode": "USD"}' \
--attribute=billingAccountId=YOUR_TARGET_PROJECT_ID