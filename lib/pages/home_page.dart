import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:dio/dio.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Telephony telephony = Telephony.instance;

  // Liste de contacts fictifs
  List<Map<String, String>> contacts = [];

  // Liste des contacts sélectionnés
  List<Map<String, String>> selectedContacts = [];

  // Contrôleur pour le champ de saisie du message
  final TextEditingController messageController = TextEditingController();

  // Contrôleur pour le champ de recherche
  final TextEditingController searchController = TextEditingController();

  // Instance Dio pour les requêtes HTTP
  final Dio dio = Dio();

  bool get allSelected => selectedContacts.length == contacts.length;

  @override
  void dispose() {
    messageController.dispose();
    searchController.dispose();
    dio.close();
    super.dispose();
  }

  void toggleAll() {
    setState(() {
      if (allSelected) {
        selectedContacts.clear();
      } else {
        selectedContacts = List.from(contacts);
      }
    });
  }

  void toggleContact(Map<String, String> contact) {
    setState(() {
      if (selectedContacts.contains(contact)) {
        selectedContacts.remove(contact);
      } else {
        selectedContacts.add(contact);
      }
    });
  }

  // Fonction pour rechercher les contacts
  void rechercherContacts() async {
    final searchTerm = searchController.text.trim();

    if (searchTerm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez entrer un terme de recherche."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    try {
      // Faire une requête GET vers /get_contacs avec le paramètre search
      final response = await dio.get(
        'https://admin-back.topgomabusiness.net/api/get_contacs',
        queryParameters: {'search': searchTerm},
      );

      // Afficher un message de succès (vous pouvez adapter selon votre besoin)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Recherche effectuée pour: $searchTerm"),
          backgroundColor: Colors.green,
        ),
      );

      // Convertir la réponse JSON en liste de Map<String, String>
      if (response.data is List) {
        final List<dynamic> dataList = response.data;
        setState(() {
          contacts = dataList.map((item) {
            return {
              'nom': item['nom']?.toString() ?? '',
              'numero': item['numero']?.toString() ?? '',
              'adresse': item['adresse']?.toString() ?? '',
              'reseau': item['reseau']?.toString() ?? '',
            };
          }).toList();
          // Réinitialiser les sélections après une nouvelle recherche
          selectedContacts.clear();
        });
      } else {
        throw Exception("Format de réponse invalide");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la recherche: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- Détection du type d'encodage ---
  bool _isGsm7(String text) {
    final gsm7 = RegExp(
      "^[A-Za-z0-9@£\\\$¥èéùìòÇØøÅåΔ_ΦΓΛΩΠΨΣΘΞÆæÉ!\"#¤%&'()*+,\\-./:;<=>?¡ÄÖÑÜ§¿äöñüà\\s^{}\\[~\\]|€]*\$",
    );
    return gsm7.hasMatch(text);
  }

  // --- Calcul du nombre de SMS segments ---
  Map<String, int> _calculateSmsInfo(String text) {
    int length = text.length;
    bool isGsm = _isGsm7(text);

    if (length == 0) return {"chars": 0, "segments": 0};

    int perSegment = isGsm ? 160 : 70;
    int multiSegment = isGsm ? 153 : 67;

    int segments = length <= perSegment ? 1 : (length / multiSegment).ceil();

    return {"chars": length, "segments": segments};
  }

  // --- Fonction pour envoyer les SMS ---
  void envoyerMessage() async {
    final message = messageController.text.trim();
    if (selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner au moins un contact."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le message ne peut pas être vide."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // 🔐 Vérifier les permissions SMS
    bool? granted = await telephony.requestSmsPermissions;
    if (granted != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Permission SMS refusée."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 🚀 Envoi automatique du SMS à chaque contact sélectionné
    for (var contact in selectedContacts) {
      await telephony.sendSms(to: contact['numero']!, message: message);
    }

    // ✅ Feedback utilisateur
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Message envoyé avec succès 🎉"),
        backgroundColor: Colors.green,
      ),
    );

    // Réinitialiser
    setState(() {
      messageController.clear();
      selectedContacts.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final smsInfo = _calculateSmsInfo(messageController.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Iver SMS"),
        elevation: 18.0,
        actions: [
          IconButton(
            onPressed: toggleAll,
            icon: Icon(
              allSelected ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            tooltip: allSelected ? "Tout décocher" : "Tout cocher",
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone de recherche
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: "Rechercher...",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => rechercherContacts(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: rechercherContacts,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: const Text("Rechercher"),
                ),
              ],
            ),
          ),

          // Affichage du nombre total de contacts
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  "Total: ${contacts.length} contact${contacts.length > 1 ? 's' : ''}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),

          // Liste des contacts
          Expanded(
            child: ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                final isSelected = selectedContacts.contains(contact);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (value) => toggleContact(contact),
                    ),
                    title: Text(contact['nom'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Numéro : ${contact['numero']}"),
                        Text("Adresse : ${contact['adresse']}"),
                        Text("Réseau : ${contact['reseau']}"),
                      ],
                    ),
                    trailing: const Icon(Icons.phone, color: Colors.green),
                  ),
                );
              },
            ),
          ),

          // Zone message et bouton envoyer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: messageController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: "Entrez votre message...",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),

                // Compteur caractères et SMS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Caractères : ${smsInfo['chars']}"),
                    Text(
                      "Segments : ${smsInfo['segments']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: envoyerMessage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      "Envoyer (${selectedContacts.length})",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
