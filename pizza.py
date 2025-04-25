# List 1: Pepperoni Pizza
pepperoni_pizza = ["Pepperoni", "Cheese", "Tomato Sauce"]

# List 2: Mad Dog Pizza (Spicy meat lovers)
mad_dog_pizza = ["Pepperoni", "Sausage", "Bacon", "Jalapenos", "Cheese", "Tomato Sauce"]

# List 3: Supreme Pizza
supreme_pizza = ["Pepperoni", "Sausage", "Mushrooms", "Bell Peppers", "Onions", "Olives", "Cheese", "Tomato Sauce"]

# List 4: Veggie Pizza
veggie_pizza = ["Mushrooms", "Bell Peppers", "Olives", "Onions", "Tomato Sauce", "Cheese"]

# List 5: Margherita Pizza
margherita_pizza = ["Tomato", "Mozzarella Cheese", "Basil", "Olive Oil", "Tomato Sauce"]

# List 6: Hawaiian Pizza
hawaiian_pizza = ["Ham", "Pineapple", "Cheese", "Tomato Sauce"]

# List 7: BBQ Chicken Pizza
bbq_chicken_pizza = ["Grilled Chicken", "BBQ Sauce", "Red Onion", "Cilantro", "Cheese"]


# Print all pizzas and their toppings
def print_pizzas():
    pizzas = [
        ("Pepperoni Pizza", pepperoni_pizza),
        ("Mad Dog Pizza", mad_dog_pizza),
        ("Supreme Pizza", supreme_pizza),
        ("Veggie Pizza", veggie_pizza),
        ("Margherita Pizza", margherita_pizza)
    ]
    
    for pizza_name, toppings in pizzas:
        print(f"{pizza_name}:")
        print(", ".join(toppings))
        print()

def identify_potential_pizzas(topping)
    if topping in veggie_pizza or topping in pepperoni_pizza or topping in supreme_pizza or topping in margherita_pizza or bbq_chicken_pizza or toppingi in hawaiian_pizza
        print("either veggie, or pepperoni, or supreme, or margherita, or bbq chicken, or hawaiian")
    
