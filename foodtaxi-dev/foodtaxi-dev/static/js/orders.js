async function loadOrders() {
  const container = document.getElementById("ordersContainer");
  container.innerHTML = "Loading orders...";

  try {
    const res = await fetch("/orders_data");
    const orders = await res.json();

    if (!orders.length) {
      container.innerHTML = "<p class='empty-orders'>You have no orders yet.</p>";
      return;
    }

    container.innerHTML = orders.map(order => `
      <div class="order-card">
        <div class="order-header">
          <h3>Order #${order.order_id}</h3>
          <p>Status: <span class="order-status ${order.order_status}">${order.order_status}</span></p>
          <p>Payment Method: ${order.payment_method.toUpperCase()}</p>
          <p>Order Date: ${new Date(order.order_date).toLocaleString()}</p>
        </div>
        <div class="order-items">
          ${order.order_products.map(item => `
            <div class="order-item">
              <div class="order-item-image-wrapper">
                <img src="/static/images/profile/${item.image}" alt="${item.product_name}" class="order-item-image">
              </div>
              <div class="order-item-details-card">
                <h4>${item.product_name}</h4>
                ${item.maker ? `<p class="product-maker">by ${item.maker}</p>` : ""}
                ${item.description ? `<p class="product-description">${item.description}</p>` : ""}
                <p>Price: ₱${parseFloat(item.price_each).toFixed(2)}</p>
                <p>Quantity: ${item.quantity}</p>
                <p>Subtotal: ₱${parseFloat(item.subtotal).toFixed(2)}</p>
              </div>
            </div>
          `).join("")}
        </div>
        <div class="order-total-card">
          Total Price: ₱${parseFloat(order.total_price).toFixed(2)}
        </div>
      </div>
    `).join("");

  } catch (err) {
    console.error(err);
    container.innerHTML = "<p class='empty-orders'>Failed to load orders.</p>";
  }
}

document.addEventListener("DOMContentLoaded", loadOrders);
