import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const EsquitazosApp());
}

class EsquitazosApp extends StatelessWidget {
  const EsquitazosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Esquitazos POS & Billetera',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF0E7490),
      ),
      home: const PantallaPrincipal(),
    );
  }
}

// -----------------------------------------------------------------------------
// AYUDANTES DE FECHA NATIVOS
// -----------------------------------------------------------------------------
class Fechas {
  static String horaMinuto(DateTime f) {
    String h = f.hour.toString().padLeft(2, '0');
    String m = f.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  static String diaMesAnio(DateTime f) {
    String d = f.day.toString().padLeft(2, '0');
    String m = f.month.toString().padLeft(2, '0');
    return "$d/$m/${f.year}";
  }

  static String diaMes(DateTime f) {
    String d = f.day.toString().padLeft(2, '0');
    String m = f.month.toString().padLeft(2, '0');
    return "$d/$m";
  }

  static String nombreMesAnio(DateTime f) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return "${meses[f.month - 1]} ${f.year}";
  }

  static String nombreDiaSemana(int diaIndex) {
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    if (diaIndex >= 1 && diaIndex <= 7) return dias[diaIndex - 1];
    return "N/A";
  }
}

// -----------------------------------------------------------------------------
// MODELOS DE DATOS
// -----------------------------------------------------------------------------

class SaborInfo {
  String id;
  String nombre;
  String emoji;
  Color color;
  double precioMediano;
  double precioGrande;
  double costoLoteCompleto;
  double costoInsumosMediano;
  double costoInsumosGrande;

  SaborInfo({
    required this.id,
    required this.nombre,
    required this.emoji,
    required this.color,
    required this.precioMediano,
    required this.precioGrande,
    required this.costoLoteCompleto,
    required this.costoInsumosMediano,
    required this.costoInsumosGrande,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'emoji': emoji,
        'color': color.toARGB32(), // Limpio de avisos
        'precioMediano': precioMediano,
        'precioGrande': precioGrande,
        'costoLoteCompleto': costoLoteCompleto,
        'costoInsumosMediano': costoInsumosMediano,
        'costoInsumosGrande': costoInsumosGrande,
      };

  factory SaborInfo.fromJson(Map<String, dynamic> json) => SaborInfo(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        nombre: json['nombre'],
        emoji: json['emoji'],
        color: Color(json['color']),
        precioMediano: (json['precioMediano'] as num).toDouble(),
        precioGrande: (json['precioGrande'] as num).toDouble(),
        costoLoteCompleto: (json['costoLoteCompleto'] as num?)?.toDouble() ?? 0.0,
        costoInsumosMediano: (json['costoInsumosMediano'] as num?)?.toDouble() ?? 0.0,
        costoInsumosGrande: (json['costoInsumosGrande'] as num?)?.toDouble() ?? 0.0,
      );
}

class VentaRegistrada {
  final int numeroVentaDia;
  final DateTime fechaHora;
  final List<Map<String, dynamic>> items;
  final double total;

  VentaRegistrada({
    required this.numeroVentaDia,
    required this.fechaHora,
    required this.items,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
        'numeroVentaDia': numeroVentaDia,
        'fechaHora': fechaHora.toIso8601String(),
        'items': items,
        'total': total,
      };

  factory VentaRegistrada.fromJson(Map<String, dynamic> json) => VentaRegistrada(
        numeroVentaDia: json['numeroVentaDia'],
        fechaHora: DateTime.parse(json['fechaHora']),
        items: List<Map<String, dynamic>>.from(json['items']),
        total: (json['total'] as num).toDouble(),
      );
}

class GastoRegistrado {
  String id;
  DateTime fechaHora;
  double monto;
  String concepto;
  String categoria;
  bool esFugaz;

  GastoRegistrado({
    required this.id,
    required this.fechaHora,
    required this.monto,
    required this.concepto,
    required this.categoria,
    required this.esFugaz,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fechaHora': fechaHora.toIso8601String(),
        'monto': monto,
        'concepto': concepto,
        'categoria': categoria,
        'esFugaz': esFugaz,
      };

  factory GastoRegistrado.fromJson(Map<String, dynamic> json) => GastoRegistrado(
        id: json['id'],
        fechaHora: DateTime.parse(json['fechaHora']),
        monto: (json['monto'] as num).toDouble(),
        concepto: json['concepto'] ?? '',
        categoria: json['categoria'] ?? 'General',
        esFugaz: json['esFugaz'] ?? false,
      );
}

// -----------------------------------------------------------------------------
// PANTALLA PRINCIPAL
// -----------------------------------------------------------------------------

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indicePestana = 0;
  bool _cargandoDatos = true;
  bool _mostrarTotalAcumulado = true;

  double nivelTextoMostrador = 3.0;
  double nivelTextoTotal = 3.0;
  double nivelTextoHistorial = 3.0;

  double saldoEfectivoEnMano = 0.0;
  List<GastoRegistrado> historialGastos = [];
  List<String> categoriasGastos = [
    'Insumos / Plásticos',
    'Ingredientes / Super',
    'Gas / Carbón',
    'Personal / Mío',
    'Moto / Transporte',
    'General',
  ];

  Map<String, Map<String, Map<String, double>>> lotesPorMes = {};
  List<SaborInfo> menuSabores = [];
  Map<String, List<VentaRegistrada>> ventasPorMes = {};
  late DateTime mesVisualizadoResumen;

  final List<Color> paletaColoresDisponibles = [
    const Color(0xFFCA8A04),
    const Color(0xFFDC2626),
    const Color(0xFFEA580C),
    const Color(0xFF854D0E),
    const Color(0xFF16A34A),
    const Color(0xFF2563EB),
    const Color(0xFF9333EA),
    const Color(0xFFDB2777),
  ];

  @override
  void initState() {
    super.initState();
    mesVisualizadoResumen = DateTime.now();
    _cargarDatosDeDisco();
  }

  Future<void> _cargarDatosDeDisco() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _mostrarTotalAcumulado = prefs.getBool('mostrarTotalAcumulado') ?? true;
      nivelTextoMostrador = prefs.getDouble('nivelTextoMostrador') ?? 3.0;
      nivelTextoTotal = prefs.getDouble('nivelTextoTotal') ?? 3.0;
      nivelTextoHistorial = prefs.getDouble('nivelTextoHistorial') ?? 3.0;
      saldoEfectivoEnMano = prefs.getDouble('saldoEfectivoEnMano') ?? 0.0;

      String? catString = prefs.getString('categoriasGastos');
      if (catString != null) {
        categoriasGastos = List<String>.from(jsonDecode(catString));
      }

      String? gastosString = prefs.getString('historialGastos');
      if (gastosString != null) {
        List<dynamic> jsonList = jsonDecode(gastosString);
        historialGastos = jsonList.map((e) => GastoRegistrado.fromJson(e)).toList();
      }

      String? saboresString = prefs.getString('menuSabores');
      if (saboresString != null) {
        List<dynamic> jsonList = jsonDecode(saboresString);
        menuSabores = jsonList.map((e) => SaborInfo.fromJson(e)).toList();
      } else {
        menuSabores = [
          SaborInfo(id: '1', nombre: 'Mantequilla c/ Epazote', emoji: '🧈', color: const Color(0xFFCA8A04), precioMediano: 50.0, precioGrande: 70.0, costoLoteCompleto: 350.0, costoInsumosMediano: 7.0, costoInsumosGrande: 10.0),
          SaborInfo(id: '2', nombre: 'Caldito de Espinazo', emoji: '🍖', color: const Color(0xFFDC2626), precioMediano: 50.0, precioGrande: 70.0, costoLoteCompleto: 400.0, costoInsumosMediano: 6.0, costoInsumosGrande: 9.0),
          SaborInfo(id: '3', nombre: 'Camarón', emoji: '🦐', color: const Color(0xFFEA580C), precioMediano: 60.0, precioGrande: 80.0, costoLoteCompleto: 500.0, costoInsumosMediano: 8.0, costoInsumosGrande: 12.0),
          SaborInfo(id: '4', nombre: 'Tuétano', emoji: '🦴', color: const Color(0xFF854D0E), precioMediano: 60.0, precioGrande: 80.0, costoLoteCompleto: 450.0, costoInsumosMediano: 7.5, costoInsumosGrande: 11.0),
        ];
      }

      String? ventasString = prefs.getString('ventasPorMes');
      if (ventasString != null) {
        Map<String, dynamic> decoded = jsonDecode(ventasString);
        ventasPorMes = decoded.map((claveMes, listaVentasJson) {
          List<dynamic> lista = listaVentasJson as List<dynamic>;
          return MapEntry(claveMes, lista.map((v) => VentaRegistrada.fromJson(v)).toList());
        });
      }

      String? lotesString = prefs.getString('lotesPorMes');
      if (lotesString != null) {
        Map<String, dynamic> decoded = jsonDecode(lotesString);
        lotesPorMes = decoded.map((claveMes, mapaDiasJson) {
          Map<String, dynamic> mapaDias = mapaDiasJson as Map<String, dynamic>;
          return MapEntry(claveMes, mapaDias.map((claveDia, mapaLotesJson) {
            Map<String, dynamic> mapaLotes = mapaLotesJson as Map<String, dynamic>;
            return MapEntry(claveDia, mapaLotes.map((k, v) => MapEntry(k, (v as num).toDouble())));
          }));
        });
      }

      _cargandoDatos = false;
    });
  }

  Future<void> _guardarDatosEnDisco() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mostrarTotalAcumulado', _mostrarTotalAcumulado);
    await prefs.setDouble('nivelTextoMostrador', nivelTextoMostrador);
    await prefs.setDouble('nivelTextoTotal', nivelTextoTotal);
    await prefs.setDouble('nivelTextoHistorial', nivelTextoHistorial);
    await prefs.setDouble('saldoEfectivoEnMano', saldoEfectivoEnMano);

    await prefs.setString('categoriasGastos', jsonEncode(categoriasGastos));
    await prefs.setString('historialGastos', jsonEncode(historialGastos.map((g) => g.toJson()).toList()));
    await prefs.setString('menuSabores', jsonEncode(menuSabores.map((s) => s.toJson()).toList()));
    await prefs.setString('ventasPorMes', jsonEncode(ventasPorMes));
    await prefs.setString('lotesPorMes', jsonEncode(lotesPorMes));
  }

  String _obtenerClaveMes(DateTime fecha) => "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}";
  String _obtenerClaveDia(DateTime fecha) => "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}_${fecha.day.toString().padLeft(2, '0')}";

  void _registrarNuevaVenta(List<Map<String, dynamic>> items, double total) {
    DateTime ahora = DateTime.now();
    String claveMes = _obtenerClaveMes(ahora);

    if (!ventasPorMes.containsKey(claveMes)) {
      ventasPorMes[claveMes] = [];
    }

    int ventasHoy = ventasPorMes[claveMes]!.where((v) =>
        v.fechaHora.year == ahora.year &&
        v.fechaHora.month == ahora.month &&
        v.fechaHora.day == ahora.day).length;

    setState(() {
      ventasPorMes[claveMes]!.insert(
        0,
        VentaRegistrada(
          numeroVentaDia: ventasHoy + 1,
          fechaHora: ahora,
          items: List.from(items),
          total: total,
        ),
      );
      saldoEfectivoEnMano += total;
    });
    _guardarDatosEnDisco();
  }

  void _registrarGasto(double monto, String concepto, String categoria, bool esFugaz) {
    setState(() {
      historialGastos.insert(
        0,
        GastoRegistrado(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fechaHora: DateTime.now(),
          monto: monto,
          concepto: concepto.isEmpty ? (esFugaz ? 'Gasto Fugaz' : 'Gasto Varios') : concepto,
          categoria: categoria,
          esFugaz: esFugaz,
        ),
      );
      saldoEfectivoEnMano -= monto;
    });
    _guardarDatosEnDisco();
  }

  void _editarGasto(GastoRegistrado gastoEditado) {
    setState(() {
      int idx = historialGastos.indexWhere((g) => g.id == gastoEditado.id);
      if (idx >= 0) {
        double dif = gastoEditado.monto - historialGastos[idx].monto;
        saldoEfectivoEnMano -= dif;
        historialGastos[idx] = gastoEditado;
      }
    });
    _guardarDatosEnDisco();
  }

  void _eliminarGasto(GastoRegistrado gasto) {
    setState(() {
      saldoEfectivoEnMano += gasto.monto;
      historialGastos.removeWhere((g) => g.id == gasto.id);
    });
    _guardarDatosEnDisco();
  }

  void _actualizarSaldoManual(double nuevoSaldo) {
    setState(() => saldoEfectivoEnMano = nuevoSaldo);
    _guardarDatosEnDisco();
  }

  void _agregarCategoria(String nuevaCat) {
    if (nuevaCat.trim().isEmpty) return;
    setState(() {
      if (!categoriasGastos.contains(nuevaCat.trim())) {
        categoriasGastos.add(nuevaCat.trim());
      }
    });
    _guardarDatosEnDisco();
  }

  void _cambiarLoteSabor(DateTime fecha, String saborId, double fraccion) {
    String claveMes = _obtenerClaveMes(fecha);
    String claveDia = _obtenerClaveDia(fecha);

    setState(() {
      if (!lotesPorMes.containsKey(claveMes)) lotesPorMes[claveMes] = {};
      if (!lotesPorMes[claveMes]!.containsKey(claveDia)) lotesPorMes[claveMes]![claveDia] = {};
      lotesPorMes[claveMes]![claveDia]![saborId] = fraccion;
    });
    _guardarDatosEnDisco();
  }

  void _toggleOjito() {
    setState(() => _mostrarTotalAcumulado = !_mostrarTotalAcumulado);
    _guardarDatosEnDisco();
  }

  void _eliminarVenta(DateTime fechaVenta, VentaRegistrada venta) {
    String claveMes = _obtenerClaveMes(fechaVenta);
    setState(() {
      if (ventasPorMes.containsKey(claveMes)) {
        ventasPorMes[claveMes]!.removeWhere((v) => v.fechaHora == venta.fechaHora && v.total == venta.total);
        saldoEfectivoEnMano -= venta.total;
      }
    });
    _guardarDatosEnDisco();
  }

  void _guardarSabor(SaborInfo saborEditado) {
    setState(() {
      int idx = menuSabores.indexWhere((s) => s.id == saborEditado.id);
      if (idx >= 0) {
        menuSabores[idx] = saborEditado;
      } else {
        menuSabores.add(saborEditado);
      }
    });
    _guardarDatosEnDisco();
  }

  void _eliminarSabor(String id) {
    setState(() {
      menuSabores.removeWhere((s) => s.id == id);
      lotesPorMes.forEach((mes, dias) {
        dias.forEach((dia, mapa) => mapa.remove(id));
      });
    });
    _guardarDatosEnDisco();
  }

  void _cambiarMesResumen(int delta) {
    setState(() {
      mesVisualizadoResumen = DateTime(mesVisualizadoResumen.year, mesVisualizadoResumen.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoDatos) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.cyan)),
      );
    }

    String claveMesActual = _obtenerClaveMes(DateTime.now());
    List<VentaRegistrada> ventasMesActual = ventasPorMes[claveMesActual] ?? [];

    final paginas = [
      CajaRapidaVista(
        menuSabores: menuSabores,
        historialVentasMes: ventasMesActual,
        nivelTextoMostrador: nivelTextoMostrador,
        nivelTextoTotal: nivelTextoTotal,
        onVentaCompletada: _registrarNuevaVenta,
        onEliminarVenta: (v) => _eliminarVenta(v.fechaHora, v),
      ),
      BilleteraVista(
        saldoEfectivoEnMano: saldoEfectivoEnMano,
        historialGastos: historialGastos,
        categoriasGastos: categoriasGastos,
        onRegistrarGasto: _registrarGasto,
        onEditarGasto: _editarGasto,
        onEliminarGasto: _eliminarGasto,
        onActualizarSaldoManual: _actualizarSaldoManual,
        onAgregarCategoria: _agregarCategoria,
      ),
      HistorialPorDiaVista(
        ventasPorMes: ventasPorMes,
        menuSabores: menuSabores,
        lotesPorMes: lotesPorMes,
        nivelTextoHistorial: nivelTextoHistorial,
        mostrarTotalAcumulado: _mostrarTotalAcumulado,
        onToggleOjito: _toggleOjito,
        onEliminarVenta: _eliminarVenta,
        onCambiarLote: _cambiarLoteSabor,
      ),
      ResumenMesVista(
        ventasPorMes: ventasPorMes,
        menuSabores: menuSabores,
        lotesPorMes: lotesPorMes,
        mesVisualizado: mesVisualizadoResumen,
        onCambiarMes: _cambiarMesResumen,
      ),
      AjustesVista(
        menuSabores: menuSabores,
        paletaColores: paletaColoresDisponibles,
        nivelTextoMostrador: nivelTextoMostrador,
        nivelTextoTotal: nivelTextoTotal,
        nivelTextoHistorial: nivelTextoHistorial,
        onCambiarNivelMostrador: (v) {
          setState(() => nivelTextoMostrador = v);
          _guardarDatosEnDisco();
        },
        onCambiarNivelTotal: (v) {
          setState(() => nivelTextoTotal = v);
          _guardarDatosEnDisco();
        },
        onCambiarNivelHistorial: (v) {
          setState(() => nivelTextoHistorial = v);
          _guardarDatosEnDisco();
        },
        onGuardarSabor: _guardarSabor,
        onEliminarSabor: _eliminarSabor,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _indicePestana,
          children: paginas,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indicePestana,
        onTap: (index) => setState(() => _indicePestana = index),
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Caja'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Billetera'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Balance Día'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Resumen Mes'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. CAJA RÁPIDA
// -----------------------------------------------------------------------------
class CajaRapidaVista extends StatefulWidget {
  final List<SaborInfo> menuSabores;
  final List<VentaRegistrada> historialVentasMes;
  final double nivelTextoMostrador;
  final double nivelTextoTotal;
  final Function(List<Map<String, dynamic>>, double) onVentaCompletada;
  final Function(VentaRegistrada) onEliminarVenta;

  const CajaRapidaVista({
    super.key,
    required this.menuSabores,
    required this.historialVentasMes,
    required this.nivelTextoMostrador,
    required this.nivelTextoTotal,
    required this.onVentaCompletada,
    required this.onEliminarVenta,
  });

  @override
  State<CajaRapidaVista> createState() => _CajaRapidaVistaState();
}

class _CajaRapidaVistaState extends State<CajaRapidaVista> {
  List<Map<String, dynamic>> itemsCarrito = [];
  double totalOrdenActual = 0.0;
  Timer? _timerGracia;
  int _segundosRestantes = 5;
  Timer? _timerCuentaAtras;
  bool enFaseCongelada = false;
  Timer? _timerRefrescoTiempo;

  @override
  void initState() {
    super.initState();
    _timerRefrescoTiempo = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timerGracia?.cancel();
    _timerCuentaAtras?.cancel();
    _timerRefrescoTiempo?.cancel();
    super.dispose();
  }

  String _formatearTiempoHace(DateTime fechaHora) {
    final diferencia = DateTime.now().difference(fechaHora);
    if (diferencia.inSeconds < 45) {
      return 'hace ${diferencia.inSeconds}s';
    } else if (diferencia.inMinutes < 60) {
      return 'hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'hace ${diferencia.inHours}h';
    } else {
      return 'hace ${diferencia.inDays}d';
    }
  }

  void _agregarProducto(String idSabor, String emoji, String sabor, String tamano, double precio) {
    if (enFaseCongelada) {
      setState(() {
        itemsCarrito.clear();
        totalOrdenActual = 0.0;
        enFaseCongelada = false;
      });
    }

    setState(() {
      itemsCarrito.add({
        'saborId': idSabor,
        'emoji': emoji,
        'sabor': sabor,
        'tamano': tamano,
        'precio': precio,
      });
      totalOrdenActual += precio;
      _segundosRestantes = 5;
    });

    _iniciarTemporizadores();
  }

  void _ajustarTotalManual(double cambio) {
    if (itemsCarrito.isEmpty || enFaseCongelada) return;
    setState(() {
      totalOrdenActual += cambio;
      if (totalOrdenActual < 0) totalOrdenActual = 0;
      _segundosRestantes = 5;
    });
    _iniciarTemporizadores();
  }

  void _deshacerUltimo() {
    if (itemsCarrito.isEmpty || enFaseCongelada) return;
    setState(() {
      var ultimo = itemsCarrito.removeLast();
      totalOrdenActual -= (ultimo['precio'] as double);
      if (totalOrdenActual < 0) totalOrdenActual = 0;
      if (itemsCarrito.isEmpty) {
        _cancelarTemporizadores();
        totalOrdenActual = 0.0;
      }
    });
  }

  void _iniciarTemporizadores() {
    _timerGracia?.cancel();
    _timerCuentaAtras?.cancel();

    _timerCuentaAtras = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_segundosRestantes > 1) {
        setState(() => _segundosRestantes--);
      } else {
        timer.cancel();
      }
    });

    _timerGracia = Timer(const Duration(seconds: 5), _congelarYGuardarOrden);
  }

  void _cancelarTemporizadores() {
    _timerGracia?.cancel();
    _timerCuentaAtras?.cancel();
    _segundosRestantes = 5;
  }

  void _congelarYGuardarOrden() {
    if (itemsCarrito.isEmpty || !mounted) return;
    widget.onVentaCompletada(itemsCarrito, totalOrdenActual);
    setState(() => enFaseCongelada = true);
    _timerCuentaAtras?.cancel();

    Timer(const Duration(seconds: 15), () {
      if (mounted && enFaseCongelada) {
        setState(() {
          itemsCarrito.clear();
          totalOrdenActual = 0.0;
          enFaseCongelada = false;
          _segundosRestantes = 5;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTime ahora = DateTime.now();
    final ultimas3Hoy = widget.historialVentasMes.where((v) =>
      v.fechaHora.year == ahora.year &&
      v.fechaHora.month == ahora.month &&
      v.fechaHora.day == ahora.day
    ).take(3).toList();

    double fontBoton = 10.0 + (widget.nivelTextoMostrador * 2.0);
    double fontPrecio = 12.0 + (widget.nivelTextoMostrador * 2.0);
    double fontTotalNum = 20.0 + (widget.nivelTextoTotal * 2.5);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1E293B),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🕒 Últimas Ventas de Hoy:', style: TextStyle(color: Colors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (ultimas3Hoy.isEmpty)
                const Text('Esperando primera venta del día...', style: TextStyle(color: Colors.grey, fontSize: 11))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ultimas3Hoy.map((v) {
                      String resumen = v.items.map((i) => '${i['emoji']}${i['tamano'].substring(0, 1)}').join(', ');
                      String haceCuanto = _formatearTiempoHace(v.fechaHora);

                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '#${v.numeroVentaDia} ➔ $resumen (\$${v.total.toStringAsFixed(0)})',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.cyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                haceCuanto,
                                style: const TextStyle(fontSize: 10, color: Colors.cyan, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => widget.onEliminarVenta(v),
                              child: const Icon(Icons.close, color: Colors.redAccent, size: 14),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: widget.menuSabores.length,
            itemBuilder: (context, index) {
              final sabor = widget.menuSabores[index];
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(sabor.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(sabor.nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _BotonPop(
                              label: '${sabor.emoji} MEDIANO',
                              precio: sabor.precioMediano,
                              color: sabor.color,
                              fontSizeLabel: fontBoton,
                              fontSizePrecio: fontPrecio,
                              onTap: () => _agregarProducto(sabor.id, sabor.emoji, sabor.nombre, 'Mediano', sabor.precioMediano),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _BotonPop(
                              label: '${sabor.emoji} GRANDE',
                              precio: sabor.precioGrande,
                              color: sabor.color,
                              fontSizeLabel: fontBoton,
                              fontSizePrecio: fontPrecio,
                              onTap: () => _agregarProducto(sabor.id, sabor.emoji, sabor.nombre, 'Grande', sabor.precioGrande),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (itemsCarrito.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.cyan, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      itemsCarrito.map((e) => '${e['emoji']} ${e['tamano']}').join(' + '),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                if (!enFaseCongelada) ...[
                  InkWell(
                    onTap: () => _ajustarTotalManual(-5.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent)),
                      child: const Text('- \$5', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _ajustarTotalManual(5.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.greenAccent)),
                      child: const Text('+ \$5', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: _deshacerUltimo,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                    child: const Text('DESHACER', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                ]
              ],
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: enFaseCongelada
              ? const Color(0xFF15803D)
              : (itemsCarrito.isNotEmpty ? const Color(0xFF0284C7) : const Color(0xFF1E293B)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enFaseCongelada
                          ? '✅ ORDEN COBRADA'
                          : (itemsCarrito.isNotEmpty ? '⏳ Guardando automáticamente en ${_segundosRestantes}s...' : 'Esperando cliente...'),
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '\$${totalOrdenActual.toStringAsFixed(2)} MXN',
                      style: TextStyle(fontSize: fontTotalNum, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (enFaseCongelada) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    minimumSize: const Size(90, 36),
                  ),
                  onPressed: () {
                    setState(() {
                      itemsCarrito.clear();
                      totalOrdenActual = 0.0;
                      enFaseCongelada = false;
                    });
                  },
                  child: const Text('SIGUIENTE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ]
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 2. BILLETERA
// -----------------------------------------------------------------------------
class BilleteraVista extends StatefulWidget {
  final double saldoEfectivoEnMano;
  final List<GastoRegistrado> historialGastos;
  final List<String> categoriasGastos;
  final Function(double, String, String, bool) onRegistrarGasto;
  final Function(GastoRegistrado) onEditarGasto;
  final Function(GastoRegistrado) onEliminarGasto;
  final Function(double) onActualizarSaldoManual;
  final Function(String) onAgregarCategoria;

  const BilleteraVista({
    super.key,
    required this.saldoEfectivoEnMano,
    required this.historialGastos,
    required this.categoriasGastos,
    required this.onRegistrarGasto,
    required this.onEditarGasto,
    required this.onEliminarGasto,
    required this.onActualizarSaldoManual,
    required this.onAgregarCategoria,
  });

  @override
  State<BilleteraVista> createState() => _BilleteraVistaState();
}

class _BilleteraVistaState extends State<BilleteraVista> {
  final TextEditingController _montoFugazCtrl = TextEditingController();

  @override
  void dispose() {
    _montoFugazCtrl.dispose();
    super.dispose();
  }

  void _abrirModalAjustarSaldo() {
    TextEditingController saldoCtrl = TextEditingController(text: widget.saldoEfectivoEnMano.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('✏️ Ajustar Dinero Real en Mano', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingresa el dinero físico exacto que traes en el bolsillo ahorita:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: saldoCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.cyan, fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Monto total (\$ MXN)', labelStyle: TextStyle(color: Colors.white60)),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.black),
            onPressed: () {
              double n = double.tryParse(saldoCtrl.text) ?? widget.saldoEfectivoEnMano;
              widget.onActualizarSaldoManual(n);
              Navigator.pop(context);
            },
            child: const Text('GUARDAR SALDO', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _abrirModalGastoDetallado() {
    TextEditingController montoCtrl = TextEditingController();
    TextEditingController conceptoCtrl = TextEditingController();
    String catSel = widget.categoriasGastos.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('📝 Registrar Gasto Detallado', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Monto (\$ MXN)', labelStyle: TextStyle(color: Colors.cyan)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: conceptoCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: '¿En qué se gastó? (Ej. Hielo, Gas)', labelStyle: TextStyle(color: Colors.cyan)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Categoría:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      InkWell(
                        onTap: () {
                          TextEditingController nuevaCatCtrl = TextEditingController();
                          showDialog(
                            context: context,
                            builder: (c) => AlertDialog(
                              backgroundColor: const Color(0xFF0F172A),
                              title: const Text('Nueva Categoría', style: TextStyle(color: Colors.white, fontSize: 14)),
                              content: TextField(controller: nuevaCatCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nombre')),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                                ElevatedButton(
                                  onPressed: () {
                                    widget.onAgregarCategoria(nuevaCatCtrl.text);
                                    Navigator.pop(c);
                                    setStateModal(() => catSel = nuevaCatCtrl.text);
                                  },
                                  child: const Text('Agregar'),
                                )
                              ],
                            ),
                          );
                        },
                        child: const Text('+ Crear Nueva', style: TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  DropdownButton<String>(
                    value: widget.categoriasGastos.contains(catSel) ? catSel : widget.categoriasGastos.first,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white),
                    items: widget.categoriasGastos.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => catSel = val);
                    },
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () {
                  double m = double.tryParse(montoCtrl.text) ?? 0.0;
                  if (m > 0) {
                    widget.onRegistrarGasto(m, conceptoCtrl.text, catSel, false);
                  }
                  Navigator.pop(context);
                },
                child: const Text('REGISTRAR SALIDA', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      ),
    );
  }

  void _abrirModalEditarGasto(GastoRegistrado gasto) {
    TextEditingController montoCtrl = TextEditingController(text: gasto.monto.toStringAsFixed(0));
    TextEditingController conceptoCtrl = TextEditingController(text: gasto.concepto);
    String catSel = gasto.categoria;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Text(gasto.esFugaz ? '⚡ Nombrar Gasto Fugaz' : 'Editar Gasto', style: const TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hora registrada: ${Fechas.horaMinuto(gasto.fechaHora)} hrs', style: const TextStyle(color: Colors.cyan, fontSize: 11)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Monto (\$ MXN)', labelStyle: TextStyle(color: Colors.cyan)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: conceptoCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Nombre / Concepto', labelStyle: TextStyle(color: Colors.cyan)),
                  ),
                  const SizedBox(height: 14),
                  DropdownButton<String>(
                    value: widget.categoriasGastos.contains(catSel) ? catSel : widget.categoriasGastos.first,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white),
                    items: widget.categoriasGastos.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => catSel = val);
                    },
                  )
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  widget.onEliminarGasto(gasto);
                  Navigator.pop(context);
                },
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.black),
                onPressed: () {
                  gasto.monto = double.tryParse(montoCtrl.text) ?? gasto.monto;
                  gasto.concepto = conceptoCtrl.text;
                  gasto.categoria = catSel;
                  gasto.esFugaz = false;
                  widget.onEditarGasto(gasto);
                  Navigator.pop(context);
                },
                child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💳 Tu Billetera Real', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('💵 Dinero Físico en Mano', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.cyan, size: 20),
                        tooltip: 'Ajustar Saldo Real',
                        onPressed: _abrirModalAjustarSaldo,
                      )
                    ],
                  ),
                  Text(
                    '\$${widget.saldoEfectivoEnMano.toStringAsFixed(2)} MXN',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: widget.saldoEfectivoEnMano >= 0 ? Colors.cyan : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Se suma automáticamente con cada venta cobrada.', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent, width: 1)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt, color: Colors.amberAccent, size: 20),
                      SizedBox(width: 6),
                      Text('Gasto Fugaz Express', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _montoFugazCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'Ej. 70',
                            hintStyle: const TextStyle(color: Colors.white24),
                            prefixText: '\$ ',
                            prefixStyle: const TextStyle(color: Colors.cyan, fontSize: 18),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          double m = double.tryParse(_montoFugazCtrl.text) ?? 0.0;
                          if (m > 0) {
                            widget.onRegistrarGasto(m, '', 'General', true);
                            _montoFugazCtrl.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('⚡ Gasto de \$$m guardado con la hora actual.'), duration: const Duration(seconds: 2)),
                            );
                          }
                        },
                        child: const Text('DESCONTAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🧾 Historial de Gastos:', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 15)),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.cyan, side: const BorderSide(color: Colors.cyan)),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Gasto Detallado', style: TextStyle(fontSize: 11)),
                onPressed: _abrirModalGastoDetallado,
              )
            ],
          ),
          const SizedBox(height: 10),
          if (widget.historialGastos.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No has registrado salidas de dinero.', style: TextStyle(color: Colors.grey))))
          else
            ...widget.historialGastos.map((gasto) {
              String horaStr = Fechas.horaMinuto(gasto.fechaHora);
              String fechaStr = Fechas.diaMes(gasto.fechaHora);

              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: gasto.esFugaz ? Colors.amberAccent.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
                    child: Icon(gasto.esFugaz ? Icons.bolt : Icons.receipt, color: gasto.esFugaz ? Colors.amberAccent : Colors.redAccent, size: 18),
                  ),
                  title: Row(
                    children: [
                      Text('-\$${gasto.monto.toStringAsFixed(2)} MXN', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                        child: Text('$fechaStr $horaStr hrs', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      )
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      gasto.esFugaz ? '⚡ Gasto Fugaz (Toca para nombrar)' : '${gasto.concepto} • [${gasto.categoria}]',
                      style: TextStyle(color: gasto.esFugaz ? Colors.amberAccent : Colors.white60, fontSize: 11, fontStyle: gasto.esFugaz ? FontStyle.italic : FontStyle.normal),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () => _abrirModalEditarGasto(gasto),
                ),
              );
            }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. BALANCE DIARIO
// -----------------------------------------------------------------------------
class HistorialPorDiaVista extends StatelessWidget {
  final Map<String, List<VentaRegistrada>> ventasPorMes;
  final List<SaborInfo> menuSabores;
  final Map<String, Map<String, Map<String, double>>> lotesPorMes;
  final double nivelTextoHistorial;
  final bool mostrarTotalAcumulado;
  final VoidCallback onToggleOjito;
  final Function(DateTime, VentaRegistrada) onEliminarVenta;
  final Function(DateTime, String, double) onCambiarLote;

  const HistorialPorDiaVista({
    super.key,
    required this.ventasPorMes,
    required this.menuSabores,
    required this.lotesPorMes,
    required this.nivelTextoHistorial,
    required this.mostrarTotalAcumulado,
    required this.onToggleOjito,
    required this.onEliminarVenta,
    required this.onCambiarLote,
  });

  String _obtenerClaveMes(DateTime fecha) => "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}";
  String _obtenerClaveDia(DateTime fecha) => "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}_${fecha.day.toString().padLeft(2, '0')}";

  Map<String, List<VentaRegistrada>> _agruparVentasActualesPorDia() {
    String claveMesActual = _obtenerClaveMes(DateTime.now());
    List<VentaRegistrada> ventasMes = ventasPorMes[claveMesActual] ?? [];
    
    Map<String, List<VentaRegistrada>> agrupado = {};
    for (var venta in ventasMes) {
      String claveDia = Fechas.diaMesAnio(venta.fechaHora);
      agrupado.putIfAbsent(claveDia, () => []).add(venta);
    }
    return agrupado;
  }

  @override
  Widget build(BuildContext context) {
    final ventasAgrupadas = _agruparVentasActualesPorDia();
    final diasOrdenados = ventasAgrupadas.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    double fontSizeBase = 12.0 + (nivelTextoHistorial * 2.0);
    String mesActualNombre = Fechas.nombreMesAnio(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('📊 Balance Diario - $mesActualNombre', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: Icon(mostrarTotalAcumulado ? Icons.visibility : Icons.visibility_off, color: Colors.cyan),
            onPressed: onToggleOjito,
          )
        ],
      ),
      body: diasOrdenados.isEmpty
          ? const Center(child: Text('Sin ventas registradas este mes.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: diasOrdenados.length,
              itemBuilder: (context, index) {
                String diaNormalizado = diasOrdenados[index];
                List<VentaRegistrada> ventasDelDia = ventasAgrupadas[diaNormalizado]!;
                DateTime fechaObj = ventasDelDia.first.fechaHora;
                
                double ventaTotalBruta = ventasDelDia.fold(0.0, (sum, item) => sum + item.total);

                double gastoInsumosVariables = 0.0;
                for (var v in ventasDelDia) {
                  for (var item in v.items) {
                    String sNombre = item['sabor'] ?? '';
                    String sTamano = item['tamano'] ?? '';
                    var saborObj = menuSabores.firstWhere(
                      (s) => s.nombre == sNombre || sNombre.contains(s.nombre),
                      orElse: () => SaborInfo(id: '', nombre: '', emoji: '', color: Colors.white, precioMediano: 0, precioGrande: 0, costoLoteCompleto: 0, costoInsumosMediano: 0, costoInsumosGrande: 0),
                    );
                    if (sTamano == 'Mediano') gastoInsumosVariables += saborObj.costoInsumosMediano;
                    if (sTamano == 'Grande') gastoInsumosVariables += saborObj.costoInsumosGrande;
                  }
                }

                String claveMes = _obtenerClaveMes(fechaObj);
                String claveDia = _obtenerClaveDia(fechaObj);
                Map<String, double> lotesDelDia = lotesPorMes[claveMes]?[claveDia] ?? {};
                
                double gastoCocinadaDia = 0.0;
                lotesDelDia.forEach((saborId, fraccion) {
                  var saborObj = menuSabores.firstWhere((s) => s.id == saborId, orElse: () => menuSabores.first);
                  gastoCocinadaDia += (saborObj.costoLoteCompleto * fraccion);
                });

                double gastoTotalDia = gastoCocinadaDia + gastoInsumosVariables;
                double resultadoNeto = ventaTotalBruta - gastoTotalDia;

                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    title: Text(diaNormalizado, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: fontSizeBase)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Venta Bruta: \$${ventaTotalBruta.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            Text('Gasto Día: \$${gastoTotalDia.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mostrarTotalAcumulado
                              ? 'Ganancia Neta: \$${resultadoNeto.toStringAsFixed(2)} MXN'
                              : 'Ganancia Neta: \$ • • • • •',
                          style: TextStyle(
                            color: resultadoNeto >= 0 ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: fontSizeBase,
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Container(
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🔥 Cocinada / Lotes preparados este día:', style: TextStyle(color: Colors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...menuSabores.map((sabor) {
                              double fraccionActual = lotesDelDia[sabor.id] ?? 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text('${sabor.emoji} ${sabor.nombre}', style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [0.0, 0.33, 0.5, 1.0].map((fraccion) {
                                          bool sel = fraccionActual == fraccion;
                                          String lbl = fraccion == 0.0 ? '❌ 0' : (fraccion == 0.33 ? '⅓' : (fraccion == 0.5 ? '½' : '🟢 1.0'));
                                          return InkWell(
                                            onTap: () => onCambiarLote(fechaObj, sabor.id, fraccion),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: sel ? Colors.cyan : const Color(0xFF1E293B),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: sel ? Colors.white : Colors.white24),
                                              ),
                                              child: Text(lbl, style: TextStyle(color: sel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      ...ventasDelDia.map((venta) {
                        return Container(
                          color: const Color(0xFF0F172A),
                          child: ListTile(
                            title: Text('Venta #${venta.numeroVentaDia} - \$${venta.total.toStringAsFixed(2)} MXN', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Hora: ${Fechas.horaMinuto(venta.fechaHora)} | ${venta.items.map((i) => "${i['emoji']} ${i['tamano']}").join(', ')}',
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => onEliminarVenta(venta.fechaHora, venta),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. RESUMEN MENSUAL
// -----------------------------------------------------------------------------
class ResumenMesVista extends StatelessWidget {
  final Map<String, List<VentaRegistrada>> ventasPorMes;
  final List<SaborInfo> menuSabores;
  final Map<String, Map<String, Map<String, double>>> lotesPorMes;
  final DateTime mesVisualizado;
  final Function(int) onCambiarMes;

  const ResumenMesVista({
    super.key,
    required this.ventasPorMes,
    required this.menuSabores,
    required this.lotesPorMes,
    required this.mesVisualizado,
    required this.onCambiarMes,
  });

  String _obtenerClaveMes(DateTime fecha) => "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    String claveMesVisualizado = _obtenerClaveMes(mesVisualizado);
    List<VentaRegistrada> ventasDelMes = ventasPorMes[claveMesVisualizado] ?? [];
    Map<String, Map<String, double>> lotesDelMes = lotesPorMes[claveMesVisualizado] ?? {};

    double ventaBrutaMes = 0.0;
    double gastoInsumosMes = 0.0;
    Set<String> diasLaboradosSet = {};
    int totalTickets = ventasDelMes.length;

    Map<String, int> medianosPorSabor = {};
    Map<String, int> grandesPorSabor = {};
    Map<String, double> ventaBrutaPorSabor = {};

    Map<int, double> ventaPorDiaSemana = {};
    Map<int, double> ventaPorHora = {};

    for (var v in ventasDelMes) {
      ventaBrutaMes += v.total;
      diasLaboradosSet.add(_obtenerClaveDia(v.fechaHora));

      int diaSemana = v.fechaHora.weekday;
      int horaVenta = v.fechaHora.hour;
      ventaPorDiaSemana[diaSemana] = (ventaPorDiaSemana[diaSemana] ?? 0) + v.total;
      ventaPorHora[horaVenta] = (ventaPorHora[horaVenta] ?? 0) + v.total;

      for (var item in v.items) {
        String sNombre = item['sabor'] ?? '';
        String sTamano = item['tamano'] ?? '';
        double pVenta = (item['precio'] as num).toDouble();

        var saborObj = menuSabores.firstWhere(
          (s) => s.nombre == sNombre || sNombre.contains(s.nombre),
          orElse: () => SaborInfo(id: '', nombre: sNombre, emoji: '', color: Colors.white, precioMediano: 0, precioGrande: 0, costoLoteCompleto: 0, costoInsumosMediano: 0, costoInsumosGrande: 0),
        );

        ventaBrutaPorSabor[saborObj.nombre] = (ventaBrutaPorSabor[saborObj.nombre] ?? 0) + pVenta;

        if (sTamano == 'Mediano') {
          gastoInsumosMes += saborObj.costoInsumosMediano;
          medianosPorSabor[saborObj.nombre] = (medianosPorSabor[saborObj.nombre] ?? 0) + 1;
        } else if (sTamano == 'Grande') {
          gastoInsumosMes += saborObj.costoInsumosGrande;
          grandesPorSabor[saborObj.nombre] = (grandesPorSabor[saborObj.nombre] ?? 0) + 1;
        }
      }
    }

    double gastoCocinadasMes = 0.0;
    lotesDelMes.forEach((dia, mapaLotes) {
      mapaLotes.forEach((saborId, fraccion) {
        var saborObj = menuSabores.firstWhere((s) => s.id == saborId, orElse: () => menuSabores.first);
        gastoCocinadasMes += (saborObj.costoLoteCompleto * fraccion);
      });
    });

    double gastoTotalMes = gastoCocinadasMes + gastoInsumosMes;
    double gananciaNetaMes = ventaBrutaMes - gastoTotalMes;
    double margenGananciaPromedio = ventaBrutaMes > 0 ? (gananciaNetaMes / ventaBrutaMes * 100) : 0.0;
    double ticketPromedio = totalTickets > 0 ? (ventaBrutaMes / totalTickets) : 0.0;
    int totalDiasLaborados = diasLaboradosSet.length;

    String mejorDiaNombre = "N/A";
    if (ventaPorDiaSemana.isNotEmpty) {
      int mejorDiaId = ventaPorDiaSemana.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      mejorDiaNombre = Fechas.nombreDiaSemana(mejorDiaId);
    }

    String mejorHoraTexto = "N/A";
    if (ventaPorHora.isNotEmpty) {
      int mejorHoraId = ventaPorHora.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      mejorHoraTexto = "$mejorHoraId:00 a ${mejorHoraId + 1}:00 hrs";
    }

    String productoEstrella = "N/A";
    if (ventaBrutaPorSabor.isNotEmpty) {
      productoEstrella = ventaBrutaPorSabor.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    String mesNombreVisualizado = Fechas.nombreMesAnio(mesVisualizado);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📈 Resumen Mensual', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: const Color(0xFF0F172A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.cyan, size: 20), onPressed: () => onCambiarMes(-1)),
                Text(mesNombreVisualizado, style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.cyan, size: 20), onPressed: mesVisualizado.month == DateTime.now().month && mesVisualizado.year == DateTime.now().year ? null : () => onCambiarMes(1)),
              ],
            ),
          ),
          Expanded(
            child: ventasDelMes.isEmpty
                ? const Center(child: Text('Sin datos financieros para este mes.', style: TextStyle(color: Colors.grey)))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              const Text('💰 Ganancia Neta Limpia Real', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                '\$${gananciaNetaMes.toStringAsFixed(2)} MXN',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: gananciaNetaMes >= 0 ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white12),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _MiniDatoFinanciero(label: 'Venta Bruta', value: '\$${ventaBrutaMes.toStringAsFixed(0)}', color: Colors.white),
                                  _MiniDatoFinanciero(label: 'Gasto Total', value: '\$${gastoTotalMes.toStringAsFixed(0)}', color: Colors.orangeAccent),
                                  _MiniDatoFinanciero(label: 'Días Laborados', value: '$totalDiasLaborados días', color: Colors.cyan),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('📊 Promedios y Márgenes:', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _CardEstadisticaSimple(icon: Icons.percent, label: 'Margen Neta', value: '${margenGananciaPromedio.toStringAsFixed(1)}%', colorValue: Colors.greenAccent)),
                          const SizedBox(width: 12),
                          Expanded(child: _CardEstadisticaSimple(icon: Icons.receipt_long, label: 'Ticket Promedio', value: '\$${ticketPromedio.toStringAsFixed(1)}', colorValue: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('💡 Inteligencia de Venta:', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      _CardEstadisticaLarga(icon: Icons.star, label: 'Sabor Estrella', value: productoEstrella, colorValue: Colors.amberAccent),
                      const SizedBox(height: 10),
                      _CardEstadisticaLarga(icon: Icons.calendar_month, label: 'Día de Más Venta', value: mejorDiaNombre.toUpperCase(), colorValue: Colors.cyan),
                      const SizedBox(height: 10),
                      _CardEstadisticaLarga(icon: Icons.access_time_filled, label: 'Hora Pico de Venta', value: mejorHoraTexto, colorValue: Colors.orangeAccent),
                      const SizedBox(height: 24),
                      const Text('🍿 Desglose de Vasos Vendidos:', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      ...menuSabores.map((sabor) {
                        int totalMed = medianosPorSabor[sabor.nombre] ?? 0;
                        int totalGde = grandesPorSabor[sabor.nombre] ?? 0;
                        int totalVasos = totalMed + totalGde;
                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(backgroundColor: sabor.color, radius: 18, child: Text(sabor.emoji, style: const TextStyle(fontSize: 18))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(sabor.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text('Medianos: $totalMed  |  Grandes: $totalGde', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text('$totalVasos vasos', style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 40),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MiniDatoFinanciero extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniDatoFinanciero({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _CardEstadisticaSimple extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color colorValue;
  const _CardEstadisticaSimple({required this.icon, required this.label, required this.value, required this.colorValue});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: Colors.cyan, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                Text(value, style: TextStyle(color: colorValue, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _CardEstadisticaLarga extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color colorValue;
  const _CardEstadisticaLarga({required this.icon, required this.label, required this.value, required this.colorValue});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: colorValue, size: 26),
        title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        trailing: Text(value, style: TextStyle(color: colorValue, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
}

String _obtenerClaveDia(DateTime fecha) => "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}_${fecha.day.toString().padLeft(2, '0')}";

// -----------------------------------------------------------------------------
// 5. AJUSTES
// -----------------------------------------------------------------------------
class AjustesVista extends StatelessWidget {
  final List<SaborInfo> menuSabores;
  final List<Color> paletaColores;
  final double nivelTextoMostrador;
  final double nivelTextoTotal;
  final double nivelTextoHistorial;
  final ValueChanged<double> onCambiarNivelMostrador;
  final ValueChanged<double> onCambiarNivelTotal;
  final ValueChanged<double> onCambiarNivelHistorial;
  final Function(SaborInfo) onGuardarSabor;
  final Function(String) onEliminarSabor;

  const AjustesVista({
    super.key,
    required this.menuSabores,
    required this.paletaColores,
    required this.nivelTextoMostrador,
    required this.nivelTextoTotal,
    required this.nivelTextoHistorial,
    required this.onCambiarNivelMostrador,
    required this.onCambiarNivelTotal,
    required this.onCambiarNivelHistorial,
    required this.onGuardarSabor,
    required this.onEliminarSabor,
  });

  void _abrirModalEditar(BuildContext context, SaborInfo? sabor) {
    showDialog(
      context: context,
      builder: (context) => _DialogoEditarSabor(
        sabor: sabor,
        paletaColores: paletaColores,
        onGuardar: onGuardarSabor,
      ),
    );
  }

  void _confirmarEliminacion(BuildContext context, SaborInfo sabor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
            SizedBox(width: 8),
            Text('¿Estás seguro?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Vas a eliminar permanentemente "${sabor.nombre}". Esto no borrará las ventas pasadas.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              onEliminarSabor(sabor.id);
              Navigator.pop(context);
            },
            child: const Text('SÍ, ELIMINAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Ajustes y Costos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.cyan,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('NUEVO SABOR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        onPressed: () => _abrirModalEditar(context, null),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('🔤 Tamaños de Letra (6 Niveles):', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Botones del Mostrador: Nivel ${nivelTextoMostrador.toInt()}', style: const TextStyle(color: Colors.white)),
                  Slider(value: nivelTextoMostrador, min: 1, max: 6, divisions: 5, activeColor: Colors.cyan, onChanged: onCambiarNivelMostrador),
                  Text('Total e Indicadores: Nivel ${nivelTextoTotal.toInt()}', style: const TextStyle(color: Colors.white)),
                  Slider(value: nivelTextoTotal, min: 1, max: 6, divisions: 5, activeColor: Colors.cyan, onChanged: onCambiarNivelTotal),
                  Text('Historial y Registro: Nivel ${nivelTextoHistorial.toInt()}', style: const TextStyle(color: Colors.white)),
                  Slider(value: nivelTextoHistorial, min: 1, max: 6, divisions: 5, activeColor: Colors.cyan, onChanged: onCambiarNivelHistorial),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('🍿 Catálogo de Sabores y Costos:', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...menuSabores.map((sabor) {
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: sabor.color, child: Text(sabor.emoji, style: const TextStyle(fontSize: 20))),
                title: Text(sabor.nombre, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Venta: M \$${sabor.precioMediano.toStringAsFixed(0)} | G \$${sabor.precioGrande.toStringAsFixed(0)}\nProducción Olla (1.0): \$${sabor.costoLoteCompleto.toStringAsFixed(0)}\nVar/Vaso: M \$${sabor.costoInsumosMediano} | G \$${sabor.costoInsumosGrande}',
                    style: const TextStyle(color: Colors.cyan, fontSize: 12),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.amberAccent), onPressed: () => _abrirModalEditar(context, sabor)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmarEliminacion(context, sabor)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _DialogoEditarSabor extends StatefulWidget {
  final SaborInfo? sabor;
  final List<Color> paletaColores;
  final Function(SaborInfo) onGuardar;

  const _DialogoEditarSabor({
    required this.sabor,
    required this.paletaColores,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarSabor> createState() => _DialogoEditarSaborState();
}

class _DialogoEditarSaborState extends State<_DialogoEditarSabor> {
  late TextEditingController nombreCtrl;
  late TextEditingController emojiCtrl;
  late TextEditingController pMedianoCtrl;
  late TextEditingController pGrandeCtrl;
  late TextEditingController costoLoteCtrl;
  late TextEditingController cInsumoMedCtrl;
  late TextEditingController cInsumoGdeCtrl;
  late Color colorSeleccionado;

  @override
  void initState() {
    super.initState();
    nombreCtrl = TextEditingController(text: widget.sabor?.nombre ?? '');
    emojiCtrl = TextEditingController(text: widget.sabor?.emoji ?? '🌽');
    pMedianoCtrl = TextEditingController(text: widget.sabor?.precioMediano.toStringAsFixed(0) ?? '50');
    pGrandeCtrl = TextEditingController(text: widget.sabor?.precioGrande.toStringAsFixed(0) ?? '70');
    costoLoteCtrl = TextEditingController(text: widget.sabor?.costoLoteCompleto.toStringAsFixed(0) ?? '350');
    cInsumoMedCtrl = TextEditingController(text: widget.sabor?.costoInsumosMediano.toStringAsFixed(1) ?? '6.0');
    cInsumoGdeCtrl = TextEditingController(text: widget.sabor?.costoInsumosGrande.toStringAsFixed(1) ?? '9.0');
    colorSeleccionado = widget.sabor?.color ?? widget.paletaColores.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(widget.sabor == null ? 'Nuevo Sabor' : 'Editar ${widget.sabor!.nombre}', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre Sabor', labelStyle: TextStyle(color: Colors.cyan)), style: const TextStyle(color: Colors.white)),
            TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji (un solo emoji)', labelStyle: TextStyle(color: Colors.cyan)), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: pMedianoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'P.Venta Med (\$)', labelStyle: TextStyle(color: Colors.greenAccent)), style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: pGrandeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'P.Venta Gde (\$)', labelStyle: TextStyle(color: Colors.greenAccent)), style: const TextStyle(color: Colors.white))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: costoLoteCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Costo Producción Olla 1.0 (\$ MXN)', labelStyle: TextStyle(color: Colors.amberAccent)), style: const TextStyle(color: Colors.white)),
            Row(
              children: [
                Expanded(child: TextField(controller: cInsumoMedCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Costo Insumo/Vaso Med (\$)', labelStyle: TextStyle(color: Colors.amberAccent)), style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: cInsumoGdeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Costo Insumo/Vaso Gde (\$)', labelStyle: TextStyle(color: Colors.amberAccent)), style: const TextStyle(color: Colors.white))),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Color de Fondo en Mostrador:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.paletaColores.map((c) {
                bool sel = colorSeleccionado == c;
                return InkWell(
                  onTap: () => setState(() => colorSeleccionado = c),
                  child: CircleAvatar(backgroundColor: c, radius: 16, child: sel ? const Icon(Icons.check, color: Colors.black) : null),
                );
              }).toList(),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.black),
          onPressed: () {
            widget.onGuardar(SaborInfo(
              id: widget.sabor?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              nombre: nombreCtrl.text,
              emoji: emojiCtrl.text,
              color: colorSeleccionado,
              precioMediano: double.tryParse(pMedianoCtrl.text) ?? 50.0,
              precioGrande: double.tryParse(pGrandeCtrl.text) ?? 70.0,
              costoLoteCompleto: double.tryParse(costoLoteCtrl.text) ?? 0.0,
              costoInsumosMediano: double.tryParse(cInsumoMedCtrl.text) ?? 0.0,
              costoInsumosGrande: double.tryParse(cInsumoGdeCtrl.text) ?? 0.0,
            ));
            Navigator.pop(context);
          },
          child: const Text('GUARDAR SABOR', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// BOTÓN POP (Actualizado con .withValues para eliminar los 8 avisos)
// -----------------------------------------------------------------------------
class _BotonPop extends StatefulWidget {
  final String label;
  final double precio;
  final Color color;
  final double fontSizeLabel;
  final double fontSizePrecio;
  final VoidCallback onTap;

  const _BotonPop({
    required this.label,
    required this.precio,
    required this.color,
    required this.fontSizeLabel,
    required this.fontSizePrecio,
    required this.onTap,
  });

  @override
  State<_BotonPop> createState() => _BotonPopState();
}

class _BotonPopState extends State<_BotonPop> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.92),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.2), // Sintaxis moderna exigida por el SDK
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color, width: 1.5),
          ),
          child: Column(
            children: [
              Text(widget.label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: widget.fontSizeLabel)),
              const SizedBox(height: 4),
              Text('\$${widget.precio.toStringAsFixed(0)}', style: TextStyle(color: widget.color, fontWeight: FontWeight.bold, fontSize: widget.fontSizePrecio)),
            ],
          ),
        ),
      ),
    );
  }
}