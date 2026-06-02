from __future__ import annotations

import sqlite3
import tkinter as tk
from pathlib import Path
from tkinter import ttk


APP_DIR = Path(__file__).resolve().parent
DATA_DIR = APP_DIR / "data"
DB_PATH = DATA_DIR / "orders.db"


class OrderRepository:
    def __init__(self, db_path: Path) -> None:
        self.db_path = db_path
        DATA_DIR.mkdir(exist_ok=True)
        self._init_database()

    def connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.db_path)
        connection.row_factory = sqlite3.Row
        return connection

    def _init_database(self) -> None:
        with self.connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS customers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL UNIQUE
                );

                CREATE TABLE IF NOT EXISTS orders (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    customer_id INTEGER NOT NULL,
                    order_date TEXT NOT NULL,
                    amount REAL NOT NULL,
                    FOREIGN KEY (customer_id) REFERENCES customers(id)
                );
                """
            )

            count = connection.execute("SELECT COUNT(*) FROM customers").fetchone()[0]
            if count:
                return

            connection.executemany(
                "INSERT INTO customers (name) VALUES (?)",
                [("ООО Астек",), ("ИП Петров",), ("ООО Пламя",)],
            )
            connection.executemany(
                """
                INSERT INTO orders (customer_id, order_date, amount)
                VALUES (?, ?, ?)
                """,
                [
                    (1, "2026-05-06", 2488.00),
                    (2, "2026-06-10", 18000.00),
                    (3, "2026-07-21", 31200.00),
                    (1, "2026-08-09", 12000.00),
                    (2, "2026-09-01", 9800.00),
                ],
            )

    def customers(self) -> list[str]:
        with self.connect() as connection:
            rows = connection.execute("SELECT name FROM customers ORDER BY name").fetchall()
            return [row["name"] for row in rows]

    def orders(self, customer: str | None, sort_field: str, sort_direction: str) -> list[sqlite3.Row]:
        allowed_fields = {
            "Клиент": "c.name",
            "Дата заказа": "o.order_date",
            "Сумма заказа": "o.amount",
        }
        order_column = allowed_fields.get(sort_field, "o.order_date")
        direction = "DESC" if sort_direction == "По убыванию" else "ASC"
        params: list[str] = []
        where_sql = ""

        if customer:
            where_sql = "WHERE c.name = ?"
            params.append(customer)

        query = f"""
            SELECT o.id, c.name AS customer, o.order_date, o.amount
            FROM orders AS o
            JOIN customers AS c ON c.id = o.customer_id
            {where_sql}
            ORDER BY {order_column} {direction}, o.id ASC
        """

        with self.connect() as connection:
            return connection.execute(query, params).fetchall()


class OrderAnalyzerApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Работа с заказами")
        self.geometry("820x520")
        self.minsize(760, 460)

        self.repository = OrderRepository(DB_PATH)
        self.current_rows: list[sqlite3.Row] = []

        self.customer_var = tk.StringVar()
        self.search_var = tk.StringVar()
        self.sort_field_var = tk.StringVar(value="Дата заказа")
        self.sort_direction_var = tk.StringVar(value="По возрастанию")

        self._build_ui()
        self._load_customers()
        self.refresh_orders()

    def _build_ui(self) -> None:
        self.columnconfigure(0, weight=1)
        self.rowconfigure(2, weight=1)

        filters = ttk.Frame(self, padding=(14, 12, 14, 6))
        filters.grid(row=0, column=0, sticky="ew")
        filters.columnconfigure(1, weight=1)
        filters.columnconfigure(4, weight=1)

        ttk.Label(filters, text="Выберите заказчика:").grid(row=0, column=0, sticky="w", padx=(0, 8))
        self.customer_box = ttk.Combobox(filters, textvariable=self.customer_var, state="readonly")
        self.customer_box.grid(row=0, column=1, sticky="ew", padx=(0, 8))
        ttk.Button(filters, text="Фильтровать", command=self.refresh_orders).grid(row=0, column=2, padx=(0, 8))
        ttk.Button(filters, text="Показать все", command=self.show_all).grid(row=0, column=3, padx=(0, 16))

        ttk.Label(filters, text="Введите строку поиска:").grid(row=0, column=4, sticky="e", padx=(0, 8))
        ttk.Entry(filters, textvariable=self.search_var).grid(row=0, column=5, sticky="ew", padx=(0, 8))
        ttk.Button(filters, text="Найти", command=self.search_rows).grid(row=0, column=6)

        sorting = ttk.Frame(self, padding=(14, 4, 14, 6))
        sorting.grid(row=1, column=0, sticky="ew")
        ttk.Label(sorting, text="Выберите поле для сортировки:").pack(side="left", padx=(0, 8))
        ttk.Combobox(
            sorting,
            textvariable=self.sort_field_var,
            values=["Клиент", "Дата заказа", "Сумма заказа"],
            state="readonly",
            width=18,
        ).pack(side="left", padx=(0, 8))
        ttk.Radiobutton(sorting, text="По возрастанию", value="По возрастанию", variable=self.sort_direction_var).pack(side="left")
        ttk.Radiobutton(sorting, text="По убыванию", value="По убыванию", variable=self.sort_direction_var).pack(side="left", padx=(8, 0))
        ttk.Button(sorting, text="Сортировать", command=self.refresh_orders).pack(side="left", padx=(12, 0))

        table_frame = ttk.Frame(self, padding=(14, 4, 14, 6))
        table_frame.grid(row=2, column=0, sticky="nsew")
        table_frame.columnconfigure(0, weight=1)
        table_frame.rowconfigure(0, weight=1)

        columns = ("id", "customer", "order_date", "amount")
        self.tree = ttk.Treeview(table_frame, columns=columns, show="headings")
        self.tree.heading("id", text="Номер заказа")
        self.tree.heading("customer", text="Клиент")
        self.tree.heading("order_date", text="Дата заказа")
        self.tree.heading("amount", text="Сумма заказа")
        self.tree.column("id", width=120, anchor="center")
        self.tree.column("customer", width=260)
        self.tree.column("order_date", width=140, anchor="center")
        self.tree.column("amount", width=160, anchor="e")
        self.tree.tag_configure("found", background="#fff3a3")
        self.tree.grid(row=0, column=0, sticky="nsew")

        scrollbar = ttk.Scrollbar(table_frame, orient="vertical", command=self.tree.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        self.tree.configure(yscrollcommand=scrollbar.set)

        footer = ttk.Frame(self, padding=(14, 4, 14, 12))
        footer.grid(row=3, column=0, sticky="ew")
        self.total_orders_label = ttk.Label(footer, text="Всего заказов: 0")
        self.total_orders_label.pack(side="left")
        self.total_amount_label = ttk.Label(footer, text="Общая сумма: 0.00")
        self.total_amount_label.pack(side="left", padx=(24, 0))

    def _load_customers(self) -> None:
        self.customer_box["values"] = self.repository.customers()

    def refresh_orders(self) -> None:
        customer = self.customer_var.get() or None
        self.current_rows = self.repository.orders(
            customer=customer,
            sort_field=self.sort_field_var.get(),
            sort_direction=self.sort_direction_var.get(),
        )
        self._render_rows()

    def show_all(self) -> None:
        self.customer_var.set("")
        self.search_var.set("")
        self.refresh_orders()

    def search_rows(self) -> None:
        needle = self.search_var.get().strip().lower()
        self._render_rows(search_text=needle)

    def _render_rows(self, search_text: str = "") -> None:
        for item in self.tree.get_children():
            self.tree.delete(item)

        total_amount = 0.0
        for row in self.current_rows:
            values = (
                row["id"],
                row["customer"],
                row["order_date"],
                f"{row['amount']:.2f}",
            )
            total_amount += float(row["amount"])
            tags = ("found",) if search_text and any(search_text in str(value).lower() for value in values) else ()
            self.tree.insert("", "end", values=values, tags=tags)

        self.total_orders_label.configure(text=f"Всего заказов: {len(self.current_rows)}")
        self.total_amount_label.configure(text=f"Общая сумма: {total_amount:.2f}")


if __name__ == "__main__":
    app = OrderAnalyzerApp()
    app.mainloop()

