# 🏙️ Radar Kochala: Sistema de Gestión Cívica

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white) ![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white) ![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white) ![MVC](https://img.shields.io/badge/Patr%C3%B3n-MVC%20%2B%20Provider-orange?style=for-the-badge)

**Radar Kochala** es una plataforma colaborativa y ciudadana multiplataforma diseñada para conectar a los ciudadanos con sus autoridades municipales. Permite el reporte, seguimiento y gestión eficiente de problemas urbanos (baches, iluminación, seguridad, etc.) mediante geolocalización en tiempo real y gamificación.

---

## 🏗️ Arquitectura y Patrones de Diseño

El proyecto está estructurado bajo una **Arquitectura en Capas** fuertemente influenciada por el patrón **MVC (Model-View-Controller)** adaptado para Flutter mediante el uso del patrón **Provider** y el **Patrón Repositorio (Repository Pattern)**.

1. **Patrón Repositorio (`data/repositories`):** Aísla la lógica de conexión a datos (Supabase) del resto de la aplicación. `ReportRepository` se encarga de las consultas SQL, inserciones y mapeo de JSON a objetos genéricos de Dart (`Report`).
2. **Patrón Controlador de Estado (`controllers`):** `ReportController` actúa como el intermediario (ViewModel/Controller) utilizando `ChangeNotifier`. Mantiene en memoria la lista de reportes y notifica a las vistas (Views) de manera reactiva cada vez que hay un filtro, una eliminación o un nuevo reporte, minimizando lecturas a la base de datos.
3. **Inyección de Dependencias (DI):** Los controladores y servicios se proveen en la raíz del árbol de widgets (`main.dart`) usando `MultiProvider`, garantizando que cualquier pantalla pueda acceder al estado global de manera segura y sin acoplamiento.

---

## 📂 Estructura de Carpetas (Directorio `lib/`)

La aplicación promueve la escalabilidad y el código limpio (Clean Code) dividiendo sus responsabilidades en directorios semánticos:

```text
lib/
├── controllers/          # Lógica de negocio y estado reactivo.
│   └── report_controller.dart  # Centraliza el flujo de reportes (CRUD y Notificaciones).
├── core/                 # Configuraciones transversales y estilos.
│   └── theme/            # Tokens de diseño (Colores, Tipografías, AppTheme).
├── data/                 # Capa de acceso a datos.
│   ├── models/           # Clases puras de Dart (ej. report.dart, perfiles).
│   └── repositories/     # Consultas directas a Supabase.
├── services/             # Lógica independiente de la UI (Singletons/Clases Estáticas).
│   ├── ai_validation_service.dart  # Validaciones inteligentes y anti-fraude.
│   ├── offline_sync_service.dart   # Sincronización asíncrona cuando no hay internet.
│   └── pdf_report_service.dart     # Generación nativa de documentos PDF.
├── views/                # Pantallas (UI) divididas por módulos o roles.
│   ├── auth/             # Vistas de Login y Registro.
│   ├── home/             # Leaderboard (Gamificación) y Home ciudadano.
│   ├── map/              # Vista interactiva central de mapas y GPS.
│   ├── profile/          # Gestión de usuario, estado y sesión.
│   ├── reports/          # Lógica de formularios (GPS, Cámara) y pantalla de Detalles.
│   ├── role/             # Enrutador de selección de tipo de cuenta (Staff vs Ciudadano).
│   ├── staff/            # El macro-módulo administrativo (Dashboards, Métricas, Calendario).
│   └── widgets/          # Componentes visuales reutilizables (Botones, Tarjetas, StatusPills).
└── main.dart             # Punto de entrada de la aplicación y Supabase.
```

---

## ✨ Funciones Detalladas por Módulo

### 🧑‍🤝‍🧑 Módulo Ciudadano (Participación Activa)
* 🗺️ **Mapa Interactivo de Exploración (`map_explore_view.dart`):**
  * Localización GPS en vivo mediante `geolocator`.
  * **Clustering Avanzado:** Agrupa automáticamente decenas de reportes en burbujas dinámicas utilizando `flutter_map_marker_cluster` para evitar saturación visual y mejorar el rendimiento de renderizado.
  * Marcadores semánticos que indican el tipo de problema (ícono/color) y su progreso actual (mediante un anillo exterior de estado).
* 📸 **Asistente de Nuevos Reportes (`new_report_view.dart`):**
  * Interfaz guiada de 3 fases: Selección precisa con arrastre de pin en el mapa interactivo, captura de evidencia (Cámara o Galería) usando `image_picker`, y categorización paramétrica (gravedad, descripción).
* 🏆 **Sistema de Gamificación (`leaderboard_view.dart`):**
  * Premia la participación cívica otorgando "puntos de karma". El módulo clasifica a los usuarios con más aportes legítimos, incentivando el desarrollo colaborativo de la comunidad.

### 🏢 Módulo Administrativo (Staff / Alcaldía)
Ubicado de forma centralizada en `admin_dashboard_view.dart`, se compone de 4 subsistemas maestros independientes:
1. 📊 **Dashboards & Métricas en Vivo (`_MetricsTab`):**
   * Computación matemática en memoria de totales, tasa de resolución porcentual (%) y reportes pendientes.
   * Filtros temporales reactivos que ajustan todas las analíticas en tiempo real (Ej: 1 Semana, 1 Mes, 1 Año).
2. 🗓️ **Calendario de Gestión y Exportación (`_AdminCalendar`):**
   * Grilla visual que pinta mapas de calor temporales sobre los días con mayor incidencia.
   * Al hacer clic en un día (usando `GestureDetector`), se despliega una hoja interactiva (`BottomSheet`) con la traza de reportes de esas 24h.
   * **Exportación PDF Diaria:** Incorpora un servicio nativo (`PdfReportService`) que maqueta tablas vectoriales y genera un PDF del trabajo específico de ese día directamente en el dispositivo, listo para exportar o imprimir.
3. 🗺️ **Mapa Dual de Monitoreo (`_MapTab`):**
   * Modo **Heatmap** (puntos de calor críticos) y Modo **Vista Ciudadana** (que hereda el mismo sistema de clústeres interactivos del ciudadano). Los administradores pueden visualizar la evidencia fotográfica de cada incidente al hacer zoom en un cluster y click sobre su marcador particular.
4. 🔍 **Control Central de Base de Datos (`_ReportsTab`):**
   * Tabla lista con barra de búsqueda combinada y selectores paramétricos. Los alcaldes filtran por categoría o severidad en microsegundos y pueden eliminar falsos positivos de la base central de datos permanentemente gracias a diálogos de confirmación de borrado en cascada.

### 🧠 Servicios Base (`services/`)
* **Sync Offline:** Arquitectura lista para que la app no muera sin internet. Captura los datos en caché (`SharedPreferences`) y espera silenciosamente a recuperar la señal para enviarlos a Supabase (`offline_sync_service.dart`).
* **Seguridad y Anti-fraude:** Capa de protección local preparada para integrarse a APIs algorítmicas de validación que detecten duplicados o spam antes de molestar al equipo municipal (`ai_validation_service.dart`).

---

## 🚀 Instalación y Ejecución Local

### Prerrequisitos
Asegúrate de tener instalado [Flutter](https://flutter.dev/) (agregado a las variables del sistema/PATH), un IDE compatible (VS Code o Android Studio) y Git. Opcionalmente, Visual Studio 2022 con herramientas C++ si pretendes compilar la versión de escritorio nativa para PC.

1. **Clonar el repositorio y Descargar Librerías**
   ```bash
   git clone https://github.com/tu-usuario/Radar_Kochala.git
   cd Radar_Kochala
   flutter pub get
   ```

2. **Configuración del Backend (Supabase)**
   Crea un archivo `env.txt` en la raíz del proyecto y vincula tu base de datos y Storage añadiendo:
   ```env
   SUPABASE_URL=TU_URL_PROYECTO
   SUPABASE_ANON_KEY=TU_LLAVE_PUBLICA
   ```

3. **Ejecutar en entorno de pruebas**
   ```bash
   flutter run
   ```
   *(Puedes presionar la tecla `r` en consola para hacer Hot Reload y recargar instantáneamente).*

---

## 📦 Despliegue y Distribución (Producción)

Al usar un solo código fuente y motor de renderizado (Skia/Impeller), compilamos a 3 plataformas diferentes de forma 100% nativa:

### Teléfonos Móviles (Android APK)
```bash
flutter build apk --release
```
*El archivo binario final de distribución estará disponible en: `build/app/outputs/flutter-apk/app-release.apk`*

### Web Universal (Reactivo en cualquier navegador)
```bash
flutter build web --release
```
*El código HTML, JS y CSS ultraoptimizado estará en `build/web/`. Simplemente sube el contenido de esta carpeta a Vercel, Netlify o Firebase Hosting.*

### Computadoras de Escritorio (Windows .exe)
```bash
flutter build windows --release
```
*Los archivos nativos de ejecución estarán en `build/windows/x64/runner/Release/`. Recuerda empaquetar en ZIP toda esa carpeta completa (incluyendo .dlls y data) para poder instalarla en otras computadoras.*
