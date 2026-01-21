#!/usr/bin/env python3
"""
Simple test application to send telemetry data to the observability stack.

Requirements:
  pip install opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp
"""

import time
import random
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

# Configure the tracer
resource = Resource.create({"service.name": "test-application"})
provider = TracerProvider(resource=resource)

# Configure OTLP exporter
otlp_exporter = OTLPSpanExporter(
    endpoint="http://localhost:4320/v1/traces",
)

# Add span processor
processor = BatchSpanProcessor(otlp_exporter)
provider.add_span_processor(processor)

# Set the global tracer provider
trace.set_tracer_provider(provider)

# Get a tracer
tracer = trace.get_tracer(__name__)


def process_order(order_id):
    """Simulate order processing with nested spans."""
    with tracer.start_as_current_span("process_order") as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("order.value", random.randint(10, 1000))

        # Simulate validation
        validate_order(order_id)

        # Simulate payment
        process_payment(order_id)

        # Simulate shipment
        schedule_shipment(order_id)

        print(f"Order {order_id} processed successfully")


def validate_order(order_id):
    """Simulate order validation."""
    with tracer.start_as_current_span("validate_order") as span:
        span.set_attribute("order.id", order_id)
        time.sleep(random.uniform(0.1, 0.3))
        span.add_event("Order validated")


def process_payment(order_id):
    """Simulate payment processing."""
    with tracer.start_as_current_span("process_payment") as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("payment.method", random.choice(["credit_card", "paypal", "bank_transfer"]))
        time.sleep(random.uniform(0.2, 0.5))

        # Simulate occasional payment failures
        if random.random() < 0.1:
            span.set_attribute("error", True)
            span.add_event("Payment failed", {"reason": "insufficient_funds"})
            raise Exception("Payment failed: insufficient funds")

        span.add_event("Payment processed successfully")


def schedule_shipment(order_id):
    """Simulate shipment scheduling."""
    with tracer.start_as_current_span("schedule_shipment") as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("carrier", random.choice(["USPS", "FedEx", "UPS"]))
        time.sleep(random.uniform(0.1, 0.2))
        span.add_event("Shipment scheduled")


def main():
    """Main function to generate test traces."""
    print("Starting test application...")
    print("Sending traces to http://localhost:4320")
    print("Press Ctrl+C to stop\n")

    order_counter = 1

    try:
        while True:
            try:
                process_order(f"ORD-{order_counter:05d}")
            except Exception as e:
                print(f"Error processing order {order_counter}: {e}")

            order_counter += 1
            time.sleep(random.uniform(1, 3))

    except KeyboardInterrupt:
        print("\n\nStopping test application...")
        print("Flushing remaining traces...")
        provider.force_flush()
        print("Done!")


if __name__ == "__main__":
    main()
