import base64
import functions_framework
from google.cloud import billing_v1
import json


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

        message_attributes = cloud_event.data["message"].get("attributes", {})
        if 'billingAccountId' not in message_attributes:
            print("Error: 'billingAccountId' not found in attributes. Acknowledging message.")
            return

        project_id = message_attributes['billingAccountId']
        cost_amount = event_pubsub.get('costAmount', 0.0)
        budget_amount = event_pubsub.get('budgetAmount', 0.0)
    except Exception as e:
        print(f"Erro Decoding: {e}. Acknowledging message.")
        return

    project_name = f"projects/{project_id}"
    print(f"Project selected: {project_id}, cost: {cost_amount} and budget: {budget_amount}")

    if cost_amount <= budget_amount:
        print(f"Cost ({cost_amount}) in the budget ({budget_amount})")
        return

    try:
        billing_info = billing_client.get_project_billing_info(name=project_name)

        if billing_info.billing_enabled:
            print(f"Disabling the billing for the project {project_name}...")
            billing_client.update_project_billing_info(
                name=project_name,
                project_billing_info={"billing_account_name": ""},
            )
            print(f"Billing in {project_name} disabled.")
        else:
            print(f"Billing in {project_id} is disabled")

        return

    except Exception as e:
        print(f"Error to disabing - {project_name}: {e}")
        raise e
