import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  AwesomeNotifications().initialize(
    null, 
    [
      NotificationChannel(
        channelKey: 'persistent_beach_channel',
        channelName: 'Praias Próximas',
        channelDescription: 'Notificação persistente com informações da praia mais próxima',
        defaultColor: const Color(0xFF9D50DD),
        importance: NotificationImportance.High,
        channelShowBadge: true,
      ),
    ],
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const MethodChannel _channel =
      MethodChannel('com.example.locationprovider/channel');

  List<dynamic> _data = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _locationMessage = 'Localização não encontrada';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    fetchData();
    _startLocationUpdates();
  }

  void _requestPermissions() async {
  if (!await AwesomeNotifications().isNotificationAllowed()) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  final statusLocationWhenInUse = await Permission.locationWhenInUse.request();
  final statusLocationAlways = await Permission.locationAlways.request();

  if (statusLocationWhenInUse.isDenied || statusLocationAlways.isDenied) {
    print('Permissões de localização não concedidas.');
  }
}


  Future<void> fetchData() async {
    final url = Uri.parse('https://balneabilidade.ima.sc.gov.br/relatorio/mapa');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        setState(() {
          _data = jsonResponse;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Erro: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startLocationUpdates() async {
    while (true) {
      await _getCurrentLocation();
      await Future.delayed(const Duration(minutes: 1));
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final result = await _channel.invokeMethod('getLastKnownLocation')
          as Map<dynamic, dynamic>?;

      if (result != null) {
        final location = result.map(
          (key, value) => MapEntry(key as String, value as double),
        );

        setState(() {
          _locationMessage =
              'Lat: ${location['latitude']}, Lon: ${location['longitude']}';
          _findNearestBeach(location['latitude']!, location['longitude']!);
        });
      } else {
        setState(() {
          _locationMessage = 'Não foi possível obter a localização';
        });
      }
    } catch (e) {
      setState(() {
        _locationMessage = 'Erro ao obter localização: $e';
      });
      print("Erro ao obter localização: $e");
    }
  }

  void _findNearestBeach(double userLat, double userLon) {
  double minDistance = double.infinity;
  Map<String, dynamic>? nearestBeach;

  for (final ponto in _data) {
    final double pontoLat = double.parse(ponto['LATITUDE']);
    final double pontoLon = double.parse(ponto['LONGITUDE']);
    final double distance = _haversine(userLat, userLon, pontoLat, pontoLon);

    if (distance < minDistance) {
      minDistance = distance;
      nearestBeach = ponto;
    }
  }

  if (nearestBeach != null && nearestBeach['ANALISES'].isNotEmpty) {
    final condition = nearestBeach['ANALISES'][0]['CONDICAO'];
    final beachName = nearestBeach['PONTO_NOME'];

    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'persistent_beach_channel',
        title: 'Praia Mais Próxima: $beachName',
        body: 'Condição da água: $condition (Distância: ${minDistance.toStringAsFixed(2)} km)',
        notificationLayout: NotificationLayout.BigText,
      ),
    );
  }
}


  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);
    final double a =
        (1 - cos(dLat)) / 2 +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            (1 - cos(dLon)) / 2;
    return R * 2 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Balneabilidade'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _locationMessage,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage))
                      : ListView.builder(
                          itemCount: _data.length,
                          itemBuilder: (context, index) {
                            final ponto = _data[index];
                            return Card(
                              margin: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: const Icon(Icons.location_on),
                                title: Text(ponto['PONTO_NOME'] ?? 'Sem nome'),
                                subtitle: Text(
                                    ponto['LOCALIZACAO'] ?? 'Local desconhecido'),
                                onTap: () => _showAnalysisDetails(ponto),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnalysisDetails(dynamic ponto) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView(
          children: [
            ListTile(
              title: Text('Ponto: ${ponto['PONTO_NOME']}'),
              subtitle: Text('Local: ${ponto['LOCALIZACAO']}'),
            ),
            const Divider(),
            ...ponto['ANALISES'].map<Widget>((analise) {
              return ListTile(
                leading: Icon(
                  analise['CONDICAO'] == 'IMPRÓPRIO'
                      ? Icons.warning
                      : Icons.check_circle,
                  color: analise['CONDICAO'] == 'IMPRÓPRIO'
                      ? Colors.red
                      : Colors.green,
                ),
                title: Text('Data: ${analise['DATA']}'),
                subtitle: Text(
                    'Condição: ${analise['CONDICAO']}\nChuva: ${analise['CHUVA']}\nResultado: ${analise['RESULTADO']}'),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}
