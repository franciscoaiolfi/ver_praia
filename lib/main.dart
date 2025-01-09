import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'persistent_beach_channel',
        channelName: 'Praias Próximas',
        channelDescription:
            'Notificação persistente com informações da praia mais próxima',
        defaultColor: const Color(0xFF9D50DD),
        importance: NotificationImportance.High,
        channelShowBadge: true,
      ),
    ],
  );

  runApp(MaterialApp(home: MyApp()));
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
  Map<String, List<Map<String, dynamic>>> _dataByCityId = {};
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

    final statusLocationWhenInUse =
        await Permission.locationWhenInUse.request();
    final statusLocationAlways = await Permission.locationAlways.request();

    if (statusLocationWhenInUse.isDenied || statusLocationAlways.isDenied) {
      print('Permissões de localização não concedidas.');
    }
  }

  Map<String, List<Map<String, dynamic>>> groupByMunicipality(
      List<dynamic> data) {
    Map<String, List<Map<String, dynamic>>> groupedData = {};

    for (var ponto in data) {
      String cityId = ponto["MUNICIPIO_COD_IBGE"];
      String cityName = ponto["MUNICIPIO"];
      if (!groupedData.containsKey(cityId)) {
        groupedData[cityId] = [];
      }
      groupedData[cityId]!.add(ponto);
    }
    return groupedData;
  }

  Future<void> fetchData() async {
    final url =
        Uri.parse('https://balneabilidade.ima.sc.gov.br/relatorio/mapa');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final getDataByCode = groupByMunicipality(jsonResponse);
        print(getDataByCode);
        print("pegando o objeto novo");
        setState(() {
          _data = jsonResponse;
          _dataByCityId = getDataByCode;
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
      await Future.delayed(const Duration(minutes: 10));
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
          body:
              'Condição da água: $condition (Distância: ${minDistance.toStringAsFixed(2)} km)',
          notificationLayout: NotificationLayout.BigText,
        ),
      );
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);
    final double a = (1 - cos(dLat)) / 2 +
        cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) * (1 - cos(dLon)) / 2;
    return R * 2 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale('en', 'US'), // Inglês
        Locale('pt', 'BR'), // Português
      ],
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Balneabilidade',
            style: TextStyle(
              fontSize: 24,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.blueAccent,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _locationMessage,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage))
                      : ListView.builder(
                          itemCount: _dataByCityId.keys.length,
                          itemBuilder: (context, index) {
                            String cityId = _dataByCityId.keys
                                .elementAt(index); // Código IBGE
                            List<Map<String, dynamic>> points =
                                _dataByCityId[cityId]!;

                            return Card(
                              margin: const EdgeInsets.all(8.0),
                              child: ExpansionTile(
                                title: Text(
                                  points.isNotEmpty
                                      ? points[0]['MUNICIPIO'] ??
                                          'Município desconhecido'
                                      : 'Município desconhecido',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                children: points.map((ponto) {
                                  return ListTile(
                                    leading: const Icon(Icons.location_on),
                                    title: Text(
                                      '${ponto['PONTO_NOME'] ?? 'Sem nome'} - ${ponto['MUNICIPIO'] ?? 'Município desconhecido'}',
                                    ),
                                    subtitle: Text(
                                      ponto['LOCALIZACAO'] ??
                                          'Local desconhecido',
                                    ),
                                    onTap: () => _showAnalysisDetails(ponto),
                                  );
                                }).toList(),
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
    // Garantir que há análises para exibir
    final analises = ponto['ANALISES'];
    if (analises == null || analises.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sem informações'),
          content: const Text('Nenhuma análise disponível para este ponto.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
      return;
    }

    // Exibir modal com as análises
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permitir rolagem no conteúdo
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Ponto: ${ponto['PONTO_NOME'] ?? 'Sem nome'}'),
                subtitle:
                    Text('Local: ${ponto['LOCALIZACAO'] ?? 'Desconhecido'}'),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: analises.length,
                  itemBuilder: (context, index) {
                    final analise = analises[index];
                    return ListTile(
                      leading: Icon(
                        analise['CONDICAO'] == 'IMPRÓPRIO'
                            ? Icons.warning
                            : Icons.check_circle,
                        color: analise['CONDICAO'] == 'IMPRÓPRIO'
                            ? Colors.red
                            : Colors.green,
                      ),
                      title: Text('Data: ${analise['DATA'] ?? 'Indisponível'}'),
                      subtitle: Text(
                        'Condição: ${analise['CONDICAO'] ?? 'Desconhecida'}\n'
                        'Chuva: ${analise['CHUVA'] ?? 'N/A'}\n'
                        'Resultado: ${analise['RESULTADO'] ?? 'N/A'}',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
