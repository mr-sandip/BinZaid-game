import 'package:flutter/material.dart';

void main() {
  runApp(const BaghaBajariApp());
}

class BaghaBajariApp extends StatelessWidget {
  const BaghaBajariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bagha Bajari',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum GamePhase { placingTigers, placingGoats, playing }
enum Piece { empty, tiger, goat }

class _GameScreenState extends State<GameScreen> {
  // Board setup: 5x5 grid (25 positions)
  List<Piece> board = List.generate(25, (_) => Piece.empty);

  GamePhase currentPhase = GamePhase.placingTigers;
  bool isTigerTurn = true;

  int tigersPlaced = 0;
  int goatsPlaced = 0;
  int selectedIndex = -1;

  String statusMessage = "ବାଘର ପାଳି: ୪ଟି ବାଘ ଗୁଟି ବୋର୍ଡରେ ରଖନ୍ତୁ।";

  // For 10-Move Draw detection
  List<String> moveHistory = [];
  bool isDraw = false;
  String winner = "";

  // Adjacency Graph for 5x5 Grid
  final Map<int, List<int>> neighbors = {
    0: [1, 5, 6],
    1: [0, 2, 6],
    2: [1, 3, 6, 7, 8],
    3: [2, 4, 8],
    4: [3, 8, 9],
    5: [0, 6, 10],
    6: [0, 1, 2, 5, 7, 10, 11, 12],
    7: [2, 6, 8, 12],
    8: [2, 3, 4, 7, 9, 12, 13, 14],
    9: [4, 8, 14],
    10: [5, 6, 11, 15, 16],
    11: [6, 10, 12, 16],
    12: [6, 7, 8, 11, 13, 16, 17, 18],
    13: [8, 12, 14, 18],
    14: [8, 9, 13, 18, 19],
    15: [10, 16, 20],
    16: [10, 11, 12, 15, 17, 20, 21, 22],
    17: [12, 16, 18, 22],
    18: [12, 13, 14, 17, 19, 22, 23, 24],
    19: [14, 18, 24],
    20: [15, 16, 21],
    21: [16, 20, 22],
    22: [16, 17, 18, 21, 23],
    23: [18, 22, 24],
    24: [18, 19, 23],
  };

  void handleTap(int index) {
    if (winner.isNotEmpty || isDraw) return;

    setState(() {
      // Phase 1: Placing Tigers (4 Tigers)
      if (currentPhase == GamePhase.placingTigers) {
        if (board[index] == Piece.empty) {
          board[index] = Piece.tiger;
          tigersPlaced++;
          if (tigersPlaced == 4) {
            currentPhase = GamePhase.placingGoats;
            statusMessage = "ଛେଳିର ପାଳି: ୪ଟି ଛେଳି ଗୁଟି ବୋର୍ଡରେ ରଖନ୍ତୁ।";
          }
        }
      }
      // Phase 2: Placing Goats (4 Goats)
      else if (currentPhase == GamePhase.placingGoats) {
        if (board[index] == Piece.empty) {
          board[index] = Piece.goat;
          goatsPlaced++;
          if (goatsPlaced == 4) {
            currentPhase = GamePhase.playing;
            isTigerTurn = true;
            statusMessage = "ଖେଳ ଆରମ୍ଭ! ବାଘର ପାଳି (ଗୁଟି ଘୁଞ୍ଚାନ୍ତୁ)।";
          }
        }
      }
      // Phase 3: Movement & Playing Phase
      else if (currentPhase == GamePhase.playing) {
        if (selectedIndex == -1) {
          // Select piece
          if (isTigerTurn && board[index] == Piece.tiger) {
            selectedIndex = index;
          } else if (!isTigerTurn && board[index] == Piece.goat) {
            selectedIndex = index;
          }
        } else {
          // Try to move selected piece to 'index'
          if (index == selectedIndex) {
            selectedIndex = -1; // Deselect
          } else if (board[index] == Piece.empty) {
            bool moved = false;

            // Simple Neighbor Move
            if (neighbors[selectedIndex]!.contains(index)) {
              board[index] = board[selectedIndex];
              board[selectedIndex] = Piece.empty;
              moved = true;
            }
            // Tiger Jump & Eat Goat Move
            else if (isTigerTurn && canTigerJump(selectedIndex, index)) {
              int jumpedGoatIndex = getMiddleIndex(selectedIndex, index);
              board[index] = Piece.tiger;
              board[selectedIndex] = Piece.empty;
              board[jumpedGoatIndex] = Piece.empty; // Eat Goat
              moved = true;
            }

            if (moved) {
              selectedIndex = -1;
              recordMoveAndCheckDraw();

              // Check Win Conditions
              if (!board.contains(Piece.goat)) {
                winner = "ବାଘ ଜିତିଗଲା! (ସବୁ ଛେଳି କଟିଗଲେ)";
                statusMessage = winner;
              } else if (isTigersTrapped()) {
                winner = "ଛେଳି ଜିତିଗଲେ! (ବାଘ ବାନ୍ଧି ହୋଇଗଲା)";
                statusMessage = winner;
              } else {
                isTigerTurn = !isTigerTurn;
                statusMessage = isTigerTurn
                    ? "ବାଘର ପାଳି (ଗୁଟି ଘୁଞ୍ଚାନ୍ତୁ)"
                    : "ଛେଳିର ପାଳି (ଗୁଟି ଘୁଞ୍ଚାନ୍ତୁ)";
              }
            }
          }
        }
      }
    });
  }

  bool canTigerJump(int from, int to) {
    int r1 = from ~/ 5, c1 = from % 5;
    int r2 = to ~/ 5, c2 = to % 5;

    int dr = r2 - r1;
    int dc = c2 - c1;

    // Check straight or diagonal jump of distance 2
    if ((dr.abs() == 2 && dc == 0) ||
        (dr == 0 && dc.abs() == 2) ||
        (dr.abs() == 2 && dc.abs() == 2)) {
      int midR = r1 + dr ~/ 2;
      int midC = c1 + dc ~/ 2;
      int midIndex = midR * 5 + midC;

      return board[midIndex] == Piece.goat;
    }
    return false;
  }

  int getMiddleIndex(int from, int to) {
    int r1 = from ~/ 5, c1 = from % 5;
    int r2 = to ~/ 5, c2 = to % 5;
    int midR = r1 + (r2 - r1) ~/ 2;
    int midC = c1 + (c2 - c1) ~/ 2;
    return midR * 5 + midC;
  }

  bool isTigersTrapped() {
    for (int i = 0; i < 25; i++) {
      if (board[i] == Piece.tiger) {
        // Check normal moves
        for (int n in neighbors[i]!) {
          if (board[n] == Piece.empty) return false;
        }
        // Check jump moves
        for (int target = 0; target < 25; target++) {
          if (board[target] == Piece.empty && canTigerJump(i, target)) {
            return false;
          }
        }
      }
    }
    return true; // All tigers trapped
  }

  void recordMoveAndCheckDraw() {
    String currentBoardState = board.map((e) => e.name).join();
    moveHistory.add(currentBoardState);

    int occurrences =
        moveHistory.where((state) => state == currentBoardState).length;
    if (occurrences >= 10) {
      isDraw = true;
      statusMessage = "ଗେମ୍ Draw ହୋଇଗଲା! (୧୦ ଥର Move Repeat ହେଲା)";
    }
  }

  void resetGame() {
    setState(() {
      board = List.generate(25, (_) => Piece.empty);
      currentPhase = GamePhase.placingTigers;
      isTigerTurn = true;
      tigersPlaced = 0;
      goatsPlaced = 0;
      selectedIndex = -1;
      moveHistory.clear();
      isDraw = false;
      winner = "";
      statusMessage = "ବାଘର ପାଳି: ୪ଟି ବାଘ ଗୁଟି ବୋର୍ଡରେ ରଖନ୍ତୁ।";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ବାଘ ଛେଳି (Bagha Bajari)"),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              statusMessage,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 25,
                itemBuilder: (context, index) {
                  bool isSelected = index == selectedIndex;
                  return GestureDetector(
                    onTap: () => handleTap(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.yellowAccent
                            : Colors.orange.shade100,
                        border: Border.all(
                            color: isSelected ? Colors.red : Colors.brown,
                            width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: buildPieceWidget(board[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: resetGame,
            icon: const Icon(Icons.refresh),
            label: const Text("ନୂଆ ଖେଳ (Reset)"),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget buildPieceWidget(Piece piece) {
    if (piece == Piece.tiger) {
      return const Text("🐅", style: TextStyle(fontSize: 32));
    } else if (piece == Piece.goat) {
      return const Text("🐐", style: TextStyle(fontSize: 32));
    }
    return const SizedBox();
  }
}
