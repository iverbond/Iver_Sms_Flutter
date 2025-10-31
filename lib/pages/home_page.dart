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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Iver SMS",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade700,
                Colors.blue.shade600,
                Colors.blue.shade500,
              ],
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: toggleAll,
              icon: Icon(
                allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                color: Colors.white,
              ),
              tooltip: allSelected ? "Tout décocher" : "Tout cocher",
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone de recherche
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade50, Colors.white],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Rechercher un contact...",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.blue.shade600,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onSubmitted: (_) => rechercherContacts(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade700],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: rechercherContacts,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Rechercher",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Affichage du nombre total de contacts
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.blue.shade100.withOpacity(0.5),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.blue.shade200.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "Total: ${contacts.length} contact${contacts.length > 1 ? 's' : ''}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (selectedContacts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${selectedContacts.length} sélectionné${selectedContacts.length > 1 ? 's' : ''}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Liste des contacts
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Aucun contact trouvé",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Utilisez la barre de recherche pour trouver des contacts",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final isSelected = selectedContacts.contains(contact);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue.shade400
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => toggleContact(contact),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (value) =>
                                        toggleContact(contact),
                                    activeColor: Colors.blue.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                contact['nom'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade900,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.phone,
                                                    size: 14,
                                                    color:
                                                        Colors.green.shade700,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    contact['reseau'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.green.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone_android,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              contact['numero'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              contact['adresse'] ?? '',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Zone message et bouton envoyer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.grey.shade50],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Champ de message
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: messageController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Entrez votre message...",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 12),

                // Compteur caractères et SMS
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.text_fields,
                            size: 18,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Caractères : ${smsInfo['chars']}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.message, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              "${smsInfo['segments']} SMS",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Bouton envoyer
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: selectedContacts.isEmpty
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : [Colors.green.shade600, Colors.green.shade700],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selectedContacts.isEmpty
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: envoyerMessage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          "Envoyer à ${selectedContacts.length} contact${selectedContacts.length > 1 ? 's' : ''}",
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
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
