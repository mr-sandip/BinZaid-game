import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const BinzaidGameApp());
}

class BinzaidGameApp extends StatelessWidget {
  const BinzaidGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Binzaid - Baraha',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: const Color(0xFFF4ECD8),
      ),
      home: const GameModeScreen(),
    );
  }
}

// ==========================================
// 1. GAME MODE SELECTION SCREEN
// ==========================================
class GameModeScreen extends StatelessWidget {
  const GameModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Binzaid (Baraha Game)'),
        centerTitle: true,
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, size: 80, color: Colors.brown),
              const SizedBox(height: 20),
              const Text(
                'Choose Game Mode',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[600],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.people),
                label: const Text('2 Player (Pass & Play)', style: TextStyle(fontSize: 18)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GameScreen(isVsBot: false, botDifficulty: 'Easy'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[800],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.smart_toy),
                label: const Text('Play vs Bot', style: TextStyle(fontSize: 18)),
                onPressed: () {
                  _showDifficultyDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDifficultyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Bot Difficulty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Easy', 'Medium', 'Hard'].map((level) {
            return ListTile(
              title: Text(level),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameScreen(isVsBot: true, botDifficulty: level),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ==========================================
// 2. CORE GAMEPLAY SCREEN
// ==========================================
class GameScreen extends StatefulWidget {
  final bool isVsBot;
  final String botDifficulty;

  const GameScreen({super.key, required this.isVsBot, required this.botDifficulty});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Board dimensions: 5x5 grid -> 25 points indexed 0 to 24
  // Phase 1: Placing Tigers (4 tigers to place)
  // Phase 2: Placing Goats (20 goats to place one by one)
  // Phase 3: Moving pieces (Tigers move, Goats move)
  
  String gamePhase = 'PLACE_TIGERS'; // 'PLACE_TIGERS', 'PLACE_GOATS', 'MOVE'
  String turn = 'TIGER'; // 'TIGER' or 'GOAT'
  
  late List<String?> board; // 'T' for Tiger, 'G' for Goat, null for empty
  int tigersToPlace = 4;
  int goatsToPlace = 20;
  int goatsEaten = 0;
  
  int? selectedIndex;
  String message = 'Place 4 Tigers on the 4 corners of the board.';
  
  // For repeat detection (Draw condition)
  final List<String> boardHistory = [];

  @override
  void initState() {
    super.initState();
    resetGame();
  }

  void resetGame() {
    setState(() {
      board = List.filled(25, null);
      gamePhase = 'PLACE_TIGERS';
      turn = 'TIGER';
      tigersToPlace = 4;
      goatsToPlace = 20;
      goatsEaten = 0;
      selectedIndex = null;
      message = 'Tiger's Turn: Place 4 Tigers on board corners.';
      boardHistory.clear();
    });
  }

  // Define valid graph connections for 5x5 board grid + diagonals on specific nodes
  List<int> getNeighbors(int index) {
    List<int> neighbors = [];
    int row = index ~/ 5;
    int col = index % 5;

    // Orthogonal movements
    if (row > 0) neighbors.add(index - 5);
    if (row < 4) neighbors.add(index + 5);
    if (col > 0) neighbors.add(index - 1);
    if (col < 4) neighbors.add(index + 1);

    // Diagonal movements enabled on specific nodes (Standard Baraha rules: center, corners, middle nodes)
    // Even indices / central diagonals pattern
    if ((row + col) % 2 == 0) {
      if (row > 0 && col > 0) neighbors.add(index - 6);
      if (row > 0 && col < 4) neighbors.add(index - 4);
      if (row < 4 && col > 0) neighbors.add(index + 4);
      if (row < 4 && col < 4) neighbors.add(index + 6);
    }

    return neighbors;
  }

  bool isValidJump(int from, int to) {
    int r1 = from ~/ 5, c1 = from % 5;
    int r2 = to ~/ 5, c2 = to % 5;
    int midR = (r1 + r2) ~/ 2;
    int midC = (c1 + c2) ~/ 2;
    int midIndex = midR * 5 + midC;

    // Check if middle point contains a goat and destination is empty
    if (board[midIndex] == 'G' && board[to] == null) {
      // Check if straight line or valid diagonal exists between from, mid, and to
      List<int> neighborsFrom = getNeighbors(from);
      List<int> neighborsMid = getNeighbors(midIndex);
      if (neighborsFrom.contains(midIndex) && neighborsMid.contains(to)) {
        return true;
      }
    }
    return false;
  }

  void handleCellTap(int index) {
    if (checkWinConditions()) return;

    // If playing vs Bot and it's Goat turn (and user plays Tiger), ignore tap
    if (widget.isVsBot && turn == 'GOAT' && gamePhase != 'PLACE_GOATS') {
      return;
    }

    setState(() {
      if (gamePhase == 'PLACE_TIGERS') {
        // Must place on corners: 0, 4, 20, 24
        List<int> corners = [0, 4, 20, 24];
        if (corners.contains(index) && board[index] == null) {
          board[index] = 'T';
          tigersToPlace--;
          if (tigersToPlace == 0) {
            gamePhase = 'PLACE_GOATS';
            turn = 'GOAT';
            message = 'Goat's Turn: Place 20 Goats on empty spots.';
          } else {
            message = 'Place remaining Tigers on corners ($tigersToPlace left).';
          }
        } else {
          message = 'Tigers must be placed on board corners!';
        }
      } 
      else if (gamePhase == 'PLACE_GOATS') {
        if (board[index] == null) {
          board[index] = 'G';
          goatsToPlace--;
          if (goatsToPlace == 0) {
            gamePhase = 'MOVE';
            turn = 'TIGER';
            message = 'All goats placed! Tiger's turn to move.';
          } else {
            turn = (turn == 'TIGER') ? 'GOAT' : 'TIGER';
            message = 'Goat placed. Goats left: $goatsToPlace';
          }
          checkWinConditions();
          if (!widget.isVsBot && gamePhase == 'MOVE' && turn == 'GOAT') {
            // Switch turns handled
          }
        } else {
          message = 'Spot already occupied!';
        }
      } 
      else if (gamePhase == 'MOVE') {
        if (selectedIndex == null) {
          // Select piece
          if (board[index] == (turn == 'TIGER' ? 'T' : 'G')) {
            selectedIndex = index;
            message = 'Piece selected. Tap adjacent empty spot or jump over goat.';
          } else {
            message = 'Select your own piece (${turn == 'TIGER' ? 'Tiger' : 'Goat'}).';
          }
        } else {
          // Move piece
          int from = selectedIndex!;
          if (from == index) {
            selectedIndex = null;
            message = 'Deselected.';
            return;
          }

          if (turn == 'TIGER') {
            // Tiger move or jump
            List<int> neighbors = getNeighbors(from);
            if (neighbors.contains(index) && board[index] == null) {
              // Normal move
              board[index] = 'T';
              board[from] = null;
              endTurnAfterMove();
            } else if (isValidJump(from, index)) {
              // Jump/Eat move
              int midR = ((from ~/ 5) + (index ~/ 5)) ~/ 2;
              int midC = ((from % 5) + (index % 5)) ~/ 2;
              int midIndex = midR * 5 + midC;

              board[index] = 'T';
              board[from] = null;
              board[midIndex] = null;
              goatsEaten++;
              
              selectedIndex = index; // Allow consecutive jumps if possible
              message = 'Ate a goat! Jump again or tap another piece.';
              
              if (checkWinConditions()) return;
              
              // If no further jumps possible, switch turn
              if (!_canTigerJumpAnywhere(index)) {
                endTurnAfterMove();
              }
            } else {
              message = 'Invalid move for Tiger.';
            }
          } else {
            // Goat move
            List<int> neighbors = getNeighbors(from);
            if (neighbors.contains(index) && board[index] == null) {
              board[index] = 'G';
              board[from] = null;
              endTurnAfterMove();
            } else {
              message = 'Goats can only move to adjacent empty spots.';
            }
          }
        }
      }
    });

    // Trigger Bot Move if applicable
    if (widget.isVsBot && !checkWinConditions() && turn == 'GOAT' && gamePhase == 'MOVE') {
      Future.delayed(const Duration(milliseconds: 600), () => executeBotMove());
    }
  }

  bool _canTigerJumpAnywhere(int tigerIndex) {
    for (int neighbor in getNeighbors(tigerIndex)) {
      int r1 = tigerIndex ~/ 5, c1 = tigerIndex % 5;
      int r2 = neighbor ~/ 5, c2 = neighbor % 5;
      int jumpTargetR = r2 + (r2 - r1);
      int jumpTargetC = c2 + (c2 - c1);
      if (jumpTargetR >= 0 && jumpTargetR < 5 && jumpTargetC >= 0 && jumpTargetC < 5) {
        int targetIndex = jumpTargetR * 5 + jumpTargetC;
        if (board[neighbor] == 'G' && board[targetIndex] == null) {
          return true;
        }
      }
    }
    return false;
  }

  void endTurnAfterMove() {
    selectedIndex = null;
    turn = (turn == 'TIGER') ? 'GOAT' : 'TIGER';
    message = '${turn == 'TIGER' ? "Tiger" : "Goat"}'s Turn';
    
    // Record board state for repeat detection (Draw condition)
    String boardState = board.join();
    boardHistory.add(boardState);
    if (boardHistory.where((state) => state == boardState).length >= 10) {
      _showEndDialog('Draw! Position repeated 10 times.');
      return;
    }

    checkWinConditions();
  }

  bool checkWinConditions() {
    // Condition 1: Tigers win if they eat 5 goats
    if (goatsEaten >= 5) {
      _showEndDialog('Tigers Win by eating 5 goats!');
      return true;
    }

    // Condition 2: Goats win if all tigers are blocked and have no moves
    if (gamePhase == 'MOVE' && turn == 'TIGER') {
      if (isAllTigersBlocked()) {
        _showEndDialog('Goats Win! All Tigers are blocked.');
        return true;
      }
    }
    return false;
  }

  bool isAllTigersBlocked() {
    for (int i = 0; i < 25; i++) {
      if (board[i] == 'T') {
        // Check standard neighbors
        for (int n in getNeighbors(i)) {
          if (board[n] == null) return false;
        }
        // Check jump moves
        if (_canTigerJumpAnywhere(i)) return false;
      }
    }
    return true;
  }

  // ==========================================
  // 3. BOT AI LOGIC (Easy, Medium, Hard)
  // ==========================================
  void executeBotMove() {
    if (gamePhase == 'PLACE_GOATS') {
      // Bot places goat on random empty spot
      List<int> emptySpots = [];
      for (int i = 0; i < 25; i++) {
        if (board[i] == null) emptySpots.add(i);
      }
      if (emptySpots.isNotEmpty) {
        emptySpots.shuffle();
        setState(() {
          board[emptySpots.first] = 'G';
          goatsToPlace--;
          if (goatsToPlace == 0) {
            gamePhase = 'MOVE';
            turn = 'TIGER';
            message = 'All goats placed! Tiger's turn.';
          } else {
            turn = 'TIGER';
            message = 'Goats left to place: $goatsToPlace';
          }
        });
      }
    } else if (gamePhase == 'MOVE' && turn == 'GOAT') {
      // Bot moves goat based on difficulty
      List<Map<String, int>> possibleMoves = [];
      for (int i = 0; i < 25; i++) {
        if (board[i] == 'G') {
          for (int n in getNeighbors(i)) {
            if (board[n] == null) {
              possibleMoves.add({'from': i, 'to': n});
            }
          }
        }
      }

      if (possibleMoves.isEmpty) return;

      Map<String, int> chosenMove = possibleMoves.first;

      if (widget.botDifficulty == 'Easy') {
        possibleMoves.shuffle();
        chosenMove = possibleMoves.first;
      } else if (widget.botDifficulty == 'Medium') {
        // Avoid moving next to tigers if possible, else random
        possibleMoves.shuffle();
        for (var move in possibleMoves) {
          int dest = move['to']!;
          bool nearTiger = getNeighbors(dest).any((n) => board[n] == 'T');
          if (!nearTiger) {
            chosenMove = move;
            break;
          }
        }
      } else {
        // Hard: Strategic blocking & safety
        possibleMoves.shuffle();
        // Try to place goat adjacent to tiger to block it
        for (var move in possibleMoves) {
          int dest = move['to']!;
          if (getNeighbors(dest).any((n) => board[n] == 'T')) {
            chosenMove = move;
            break;
          }
        }
      }

      setState(() {
        board[chosenMove['to']!] = 'G';
        board[chosenMove['from']!] = null;
        endTurnAfterMove();
      });
    }
  }

  void _showEndDialog(String title) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.brown)),
        content: Text('Goats Eaten: $goatsEaten / 5'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
            onPressed: () {
              Navigator.pop(context);
              resetGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVsBot ? 'Vs Bot (${widget.botDifficulty})' : '2 Player Mode'),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: resetGame,
            tooltip: 'Reset Game',
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status Header Bar
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.brown[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Turn: ${turn == "TIGER" ? "🐅 Tiger" : "🐐 Goat"}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Goats Eaten: $goatsEaten/5',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (gamePhase == 'PLACE_GOATS')
                      Text('Left: $goatsToPlace', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Wooden Board UI Container
          Center(
            child: Container(
              width: 350,
              height: 350,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD2B48C), // Wooden tan color
                border: Border.all(color: Colors.brown.shade900, width: 6),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: CustomPaint(
                painter: BoardPainter(),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                  ),
                  itemCount: 25,
                  itemBuilder: (context, index) {
                    bool isSelected = selectedIndex == index;
                    String? piece = board[index];

                    return GestureDetector(
                      onTap: () => handleCellTap(index),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.amber.shade300 : Colors.transparent,
                        ),
                        child: Center(
                          child: piece == 'T'
                              ? const CircleAvatar(
                                  backgroundColor: Colors.orangeAccent,
                                  child: Text('🐅', style: TextStyle(fontSize: 20)),
                                )
                              : piece == 'G'
                                  ? const CircleAvatar(
                                      backgroundColor: Colors.white70,
                                      child: Text('🐐', style: TextStyle(fontSize: 18)),
                                    )
                                  : Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.brown[900],
                          
