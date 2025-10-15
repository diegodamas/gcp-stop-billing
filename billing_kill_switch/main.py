import base64
import functions_framework
from google.cloud import billing_v1
import json

# Triggered from a message on a Cloud Pub/Sub topic.
@functions_framework.cloud_event
def stop_billing(cloud_event):
    """Disables billing for a GCP project if its cost exceeds the budget

    Args:
        cloud_event (cloudevent.CloudEvent): The event payload from Pub/Sub.

    Returns:
        None. The function logs its actions and results to Cloud Logging.
    """

    billing_client = billing_v1.CloudBillingClient()

    try:
        event_pubsub = json.loads(base64.b64decode(cloud_event.data["message"]["data"]).decode("utf-8"))
        print(f"Event Message: {event_pubsub}")
    except Exception as e:
        print(f"Erro to decode message: {e}")
        return

    message_attributes = cloud_event.data["message"].get("attributes", {})
    if not message_attributes or 'billingAccountId' not in message_attributes:
        print("Error: project_id not found in event")
        return

    cost_amount = event_pubsub.get('costAmount', 0.0)
    budget_amount = event_pubsub.get('budgetAmount', 0.0)
    project_id = cloud_event.data['attributes']['billingAccountId']
    project_name = f"projects/{project_id}"

    print(f"Project selected: {project_id}, cost: {cost_amount} and budget: {budget_amount}")

    if cost_amount <= budget_amount:
        print(f"Anual Cost: {cost_amount}\nBudget: ({budget_amount})")
        return

    try:
        billing_info = billing_client.get_project_billing_info(name=project_name)

        if billing_info.billing_enabled:
            print(f"Disabling billing for the project {project_name}...")

            # billing_account_name without value for disable
            billing_client.update_project_billing_info(
                name=project_name,
                project_billing_info={"billing_account_name": ""},
            )
            print(f"Billing for the project {project_name} disabled")
        else:
            print(f"billing for the project {project_id} is already disabled")

    except Exception as e:
        print(f"Error to kill billing the project: {e}")
