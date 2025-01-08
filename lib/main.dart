import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<dynamic> _data = []; // Lista para armazenar os pontos
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final url =
        Uri.parse('https://balneabilidade.ima.sc.gov.br/relatorio/mapa');
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Balneabilidade'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator()) // Carregando
            : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage)) // Erro
                : ListView.builder(
                    itemCount: _data.length,
                    itemBuilder: (context, index) {
                      final ponto = _data[index];
                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(ponto['PONTO_NOME'] ?? 'Sem nome'),
                          subtitle: Text(ponto['LOCALIZACAO'] ??
                              'Localização desconhecida'),
                          onTap: () => _showAnalysisDetails(ponto),
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: fetchData,
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
