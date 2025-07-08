import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ProductListScreen(category: "전체"),
    );
  }
}

class Product {
  final String name;
  final String category;
  final int price;
  final String imagePath; //이미지 경로

  Product(this.name, this.category, this.price, this.imagePath);  //제품별로 이미지를 각각 전부 추가
}

class ProductListScreen extends StatefulWidget {
  final String category;

  ProductListScreen({required this.category});

  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  static Map<Product, int> cart = {};

  List<Product> allProducts = [
    Product("사과", "식품", 1000, "images/assets/apple.png"),
    Product("바나나", "식품", 2000, "images/assets/banana.png"),
    Product("포도", "식품", 3000, "images/assets/grape.png"),
    Product("딸기", "식품", 3000, "images/assets/strawberry.png"),
    Product("세제", "생활", 10000, "images/assets/detergent.png"),
    Product("휴지", "생활", 10000, "images/assets/tissue.png"),
    Product("전자레인지", "가전", 100000, "images/assets/microwave.png"),
    Product("TV", "가전", 300000, "images/assets/TV.png"),
    Product("엔진오일", "자동차", 30000, "images/assets/engine oil.png"),
    Product("타이어", "자동차", 50000, "images/assets/tire.png"),
    Product("블랙박스", "자동차", 300000, "images/assets/dash cam.png"),
  ];

  void _addToCart(Product product) {
    setState(() {
      if (cart.containsKey(product)) {
        cart[product] = cart[product]! + 1;
      } else {
        cart[product] = 1;
      }
    });
  }

  List<Product> _filterProducts(String category) {
    if (category == "전체") {
      return allProducts;
    }
    return allProducts.where((product) => product.category == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    List<Product> products = _filterProducts(widget.category);

    return Scaffold(
      appBar: AppBar(
        title: Text("상품 목록 (${widget.category})"),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartScreen(cart: cart),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text("카테고리 선택",
                  style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(
              title: Text("전체"),
              onTap: () {
                Navigator.pushReplacement( //pushReplacement는 뒤로가기 버튼이 없고 페이지 대체
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductListScreen(category: "전체"),
                  ),
                );
              },
            ),
            ListTile(
              title: Text("식품"),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductListScreen(category: "식품"),
                  ),
                );
              },
            ),
            ListTile(
              title: Text("생활"),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductListScreen(category: "생활"),
                  ),
                );
              },
            ),
            ListTile(
              title: Text("가전"),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductListScreen(category: "가전"),
                  ),
                );
              },
            ),
            ListTile(
              title: Text("자동차"),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductListScreen(category: "자동차"),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              radius : 25,
              backgroundImage: AssetImage(products[index].imagePath),
            ), // 상품 이미지 추가
            title: Text(products[index].name),
            subtitle: Text("${products[index].price} 원"),
            trailing: IconButton(
              icon: Icon(Icons.add_shopping_cart),
              onPressed: () {
                _addToCart(products[index]);
              },
            ),
              // 상품 상세 페이지 추가 (장바구니에도 넣고싶으면 이부분 장바구니에도 사용)
            onTap: (){
              Navigator.push( // .push 해야 네이게이션 스택에 쌓여서 전 페이지로 돌아갈 수 있게 <- 버튼이 뜸
                context,
                MaterialPageRoute(
                  builder:(context) => ProductDetailScreen(product : products[index]),
                )
              );
            }
          );
        },
      ),
    );
  }
}

//상품 상세 페이지 추가
class ProductDetailScreen extends StatelessWidget{
  final Product product;

  ProductDetailScreen({required this.product});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar : AppBar(
        title: Text(product.name),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            Container(
              decoration:BoxDecoration(
                shape: BoxShape.circle,
                image : DecorationImage(image: AssetImage(product.imagePath), fit: BoxFit.cover)
              ),
              width : 200,
              height : 200,
            ),
            SizedBox(height:40), //그림 글자 간격 떨어지게 배치
            Text(
              product.name,
              style: TextStyle(fontSize:24, fontWeight: FontWeight.bold),
            ),
            Text(
              "${product.price} 원",
              style: TextStyle(fontSize:24),
            )
          ]
        )
      )
    );
  }
}

class CartScreen extends StatefulWidget {
  final Map<Product, int> cart;

  CartScreen({required this.cart});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  void _updateQuantity(Product product, int change) {
    setState(() {
      if (widget.cart[product]! + change > 0) {
        widget.cart[product] = widget.cart[product]! + change;
      } else {
        widget.cart.remove(product);
      }
    });
  }

  int _calculateTotalPrice() {
    int total = 0;
    widget.cart.forEach((product, quantity) {
      total += product.price * quantity;
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("장바구니"),
      ),
      body: widget.cart.isEmpty
          ? Center(child: Text("장바구니가 비었습니다."))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.cart.length,
              itemBuilder: (context, index) {
                Product product = widget.cart.keys.elementAt(index);
                int quantity = widget.cart[product]!;
                return ListTile(
                  leading: CircleAvatar(
                    radius : 25,
                    backgroundImage: AssetImage(product.imagePath), //제품에 대해서 이미지 출력
                  ), // 상품 이미지 추가
                  title: Text(product.name),
                  subtitle: Text(
                    "${product.price} 원 x $quantity",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          _updateQuantity(product, -1);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          _updateQuantity(product, 1);
                        },
                      ),
                    ],
                  ), 
                    //장바구니에도 상세페이지 추가
                    onTap: (){
                      Navigator.push( // .push 해야 네이게이션 스택에 쌓여서 전 페이지로 돌아갈 수 있게 <- 버튼이 뜸
                          context,
                          MaterialPageRoute(
                            builder:(context) => ProductDetailScreen(product : product),
                          )
                      );
                    }
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "총 가격: ${_calculateTotalPrice()} 원",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text("구매 완료"),
                    content: Text("총 가격: ${_calculateTotalPrice()} 원"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setState((){
                            widget.cart.clear();
                          }); // 첫번째 기능(구매 후 장바구니 비우기)
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Text("확인"),
                      ),
                    ],
                  );
                },
              );
            },
            child: Text("구매하기"),
          ),
        ],
      ),
    );
  }
}
