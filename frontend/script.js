document.addEventListener("DOMContentLoaded", () => {
  // Small client-side table filter; database data still comes from Flask/MySQL.
  document.querySelectorAll("[data-table-search]").forEach((input) => {
    input.addEventListener("input", () => {
      const table = document.querySelector(input.dataset.tableSearch);
      if (!table) return;
      const term = input.value.toLowerCase();
      table.querySelectorAll("tbody tr").forEach((row) => {
        row.hidden = !row.textContent.toLowerCase().includes(term);
      });
    });
  });

  document.querySelectorAll("form[data-confirm]").forEach((form) => {
    form.addEventListener("submit", (event) => {
      if (!window.confirm(form.dataset.confirm)) event.preventDefault();
    });
  });

  const addItem = document.getElementById("addOrderItem");
  const items = document.getElementById("orderItems");
  if (addItem && items) {
    addItem.addEventListener("click", () => {
      const first = items.querySelector(".order-item");
      const row = first.cloneNode(true);
      row.querySelector("select").selectedIndex = 0;
      row.querySelector('input[name="quantity"]').value = "1";
      items.appendChild(row);
    });
    items.addEventListener("click", (event) => {
      if (event.target.closest(".remove-item")) {
        const rows = items.querySelectorAll(".order-item");
        if (rows.length > 1) event.target.closest(".order-item").remove();
        else {
          rows[0].querySelector("select").selectedIndex = 0;
          rows[0].querySelector('input[name="quantity"]').value = "1";
        }
      }
    });
  }
});
