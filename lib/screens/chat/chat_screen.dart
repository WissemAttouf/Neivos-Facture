// lib/screens/chat/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/particle_background.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isFirstLoad = true;

  // ✅ BASE DE CONNAISSANCES MANUELLE POUR LE COMPTABLE (Sans RAG / Sans API IA)
  final Map<String, String> _manualKnowledgeBase = {
    "facture d'achat": "Pour comptabiliser une facture d'achat d'un bien ou d'un service :\n1. Débiter le compte de charge (ex: 60x Achats).\n2. Débiter le compte de TVA déductible (4366).\n3. Créditer le compte Fournisseur (401) pour le montant TTC.",
    "facture de vente": "Pour comptabiliser une facture de vente :\n1. Débiter le compte Client (411) du montant TTC.\n2. Créditer le compte de Produit (ex: 70x Ventes) du montant HT.\n3. Créditer le compte de TVA collectée (4367).",
    "taux de tva": "En Tunisie, les taux de TVA applicables sont généralement :\n- 19% : Taux normal pour la majorité des biens et services.\n- 13% : Taux intermédiaire (ex: prestations de services spécifiques).\n- 7% : Taux réduit (ex: certains produits de première nécessité).",
    "retenue à la source": "La retenue à la source (RS) s'applique lors du paiement. Le client retient un pourcentage (ex: 1%, 1.5%, 3%, 10% ou 15% selon la législation) qu'il versera directement à l'État.\nEn comptabilité : le fournisseur débite le compte 434 (État, impôts et taxes) pour la RS subie.",
    "timbre fiscal": "Le timbre fiscal sur facture (actuellement 1,000 DT en Tunisie) est une taxe due lorsque la facture est payée au comptant. Il est à la charge de l'acheteur et vient augmenter le TTC de la facture.",
    "amortissement": "L'amortissement constate la dépréciation d'une immobilisation.\nÉcriture de dotation :\n- Débit : 681 Dotations aux amortissements\n- Crédit : 28x Amortissements de l'immobilisation.",
    "rapprochement bancaire": "Le rapprochement bancaire consiste à vérifier la concordance entre le solde du compte banque dans l'entreprise (532) et le solde figurant sur l'extrait envoyé par la banque, en identifiant les opérations en transit.",
  };

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  

        // Afficher les suggestions manuelles
        _addSuggestions([
          "Comment comptabiliser une facture d'achat ?",
          "Quel est le taux de TVA ?",
          "C'est quoi la retenue à la source ?",
          "Comment traiter le timbre fiscal ?"
        ]);

        _scrollToBottom();
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Ajouter le message de l'utilisateur
    setState(() {
      _messages.add({
        "text": text,
        "isUser": true,
        "timestamp": DateTime.now(),
      });
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    // Simuler un temps de réflexion réseau (1 seconde)
    await Future.delayed(const Duration(milliseconds: 1000));

    // ✅ RECHERCHE MANUELLE DANS LA BASE DE CONNAISSANCES
    String responseText = _searchManualResponse(text);

    setState(() {
      _messages.add({
        "text": responseText,
        "isUser": false,
        "timestamp": DateTime.now(),
      });
      _isLoading = false;
    });
    _scrollToBottom();
  }

  // ✅ FONCTION DE RECHERCHE DANS LE DICTIONNAIRE
 

    // Fallback si la question n'est pas reconnue
    return "🤖 Je suis désolé, je n'ai pas la réponse exacte à cette question dans ma base de connaissances actuelle.\n\nVous pouvez me poser des questions sur :\n- La comptabilisation d'une facture d'achat ou de vente\n- Le taux de TVA\n- La retenue à la source\n- Le timbre fiscal\n- Les amortissements\n- Le rapprochement bancaire";
  }

  void _addSuggestions(List<String> suggestions) {
    if (!mounted) return;

    setState(() {
      _messages.add({
        "text": "Suggestions de questions:",
        "isUser": false,
        "timestamp": DateTime.now(),
        "isSuggestionHeader": true,
        "suggestionsList": suggestions,
      });
    });
  }

  void _sendSuggestion(String suggestion) {
    _controller.text = suggestion;
    _sendMessage();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        
        }
      });
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/ssvg.PNG',
              height: 40,
              width: 40,
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.account_balance, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text(
              'CHAT IA', // Modification du titre ici
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expert Comptable (Local)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Réponses pré-définies (Hors Ligne)',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('En Ligne', style: TextStyle(fontSize: 10, color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: _messages.isEmpty && _isFirstLoad
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Chargement de l\'assistant...',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    if (message['isSuggestionHeader'] == true) {
                      return _buildSuggestionsWidget(message['suggestionsList']);
                    }
                    return _buildMessageBubble(message, context);
                  },
                ),
              ),

              // Indicateur de chargement
              if (_isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Recherche dans la base de données...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),

              // Zone de saisie
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_isLoading,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          hintText: _isLoading
                              ? "Recherche de réponse..."
                              : "Posez votre question comptable...",
                          hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: _controller.text.trim().isEmpty || _isLoading
                          ? Theme.of(context).disabledColor
                          : Theme.of(context).primaryColor,
                      child: IconButton(
                        onPressed: _controller.text.trim().isEmpty || _isLoading ? null : _sendMessage,
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsWidget(List<String> suggestions) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💡 Questions fréquentes :',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) {
              return ActionChip(
                label: Text(
                  suggestion,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => _sendSuggestion(suggestion),
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                labelStyle: TextStyle(color: Theme.of(context).primaryColor),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, BuildContext context) {
    final isUser = message['isUser'] as bool;
    final isError = message['isError'] == true;
    final isWelcome = message['isWelcome'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            CircleAvatar(
              radius: 20,
              backgroundColor: isError ? Colors.red : Theme.of(context).primaryColor,
              child: isError
                  ? const Icon(Icons.error, color: Colors.white, size: 18)
                  : isWelcome
                  ? const Icon(Icons.waving_hand, color: Colors.white, size: 18)
                  : const Icon(Icons.account_balance, color: Colors.white, size: 18),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).primaryColor
                    : isError
                    ? Colors.red.withOpacity(0.1)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.only(
     
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  Text(
                    message['text'] as String,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : isError
                          ? Colors.red
                          : Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message['timestamp'] as DateTime),
                    style: TextStyle(
                      color: isUser
                          ? Colors.white70
                          : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
       
            ),
        ],
      ),
    );
  }
}
