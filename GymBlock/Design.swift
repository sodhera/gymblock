import SwiftUI
import UIKit

enum GymColor {
  static let ground = adaptive(light: 0xFBF8F5, dark: 0x191617)
  static let surface = adaptive(light: 0xFFFCF9, dark: 0x292526)
  static let ink = adaptive(light: 0x231A1B, dark: 0xF8F0EB)
  static let dim = adaptive(light: 0x716769, dark: 0xBCADAF)
  static let red = Color(
    uiColor: UIColor { traits in
      let high = traits.accessibilityContrast == .high
      let hex: UInt32 =
        traits.userInterfaceStyle == .dark
        ? (high ? 0xFF8490 : 0xFF626B) : (high ? 0xAE1525 : 0xC92535)
      return UIColor(
        red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
        blue: CGFloat(hex & 255) / 255, alpha: 1)
    })
  static func adaptive(light: UInt32, dark: UInt32) -> Color {
    Color(
      uiColor: UIColor { traits in
        let hex = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(
          red: CGFloat((hex >> 16) & 255) / 255,
          green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
      })
  }
  static let action = red
  static let wash = Color(uiColor: .tertiarySystemFill)
}
struct GymButton: View {
  var title: String
  var icon: String? = nil
  var secondary = false
  var enabled = true
  var id: String = ""
  var finishSet = false
  var action: () -> Void
  private var control: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if let icon { Image(systemName: icon) }
        Text(title).font(GymType.label(17))
      }.frame(maxWidth: .infinity, minHeight: 54)
    }.disabled(!enabled).accessibilityIdentifier(id)
  }
  var body: some View {
    if #available(iOS 26.0, *) {
      if secondary {
        control.buttonStyle(.glass).tint(GymColor.red)
      } else {
        control.buttonStyle(.glassProminent).tint(Color(red: 0.79, green: 0.145, blue: 0.208))
          .foregroundStyle(.white)

      }
    } else {
      control.buttonStyle(.borderedProminent).tint(
        secondary
          ? Color(uiColor: .secondarySystemBackground) : Color(red: 0.79, green: 0.145, blue: 0.208)
      )
    }
  }
}
extension GymStore {
  func t(_ key: String) -> String {
    profile.language == "es"
      ? Spanish.v5[key] ?? Spanish.benefits[key] ?? Spanish.reset[key] ?? Spanish.journey[key] ?? Spanish.onboarding[key] ?? Spanish.redesign[key] ?? Spanish.additions[key] ?? Spanish.words[
        key] ?? key : key
  }
}
enum Spanish {
  static let onboarding: [String: String] = [
    "Replay": "Repetir",
    "Stay with your workout.": "Quédate con tu entrenamiento.",
    "How often do you work out?": "¿Cuántas veces entrenas?",
    "How long is a usual visit?": "¿Cuánto dura una visita habitual?",
    "What’s a usual workout?": "¿Cómo es tu entrenamiento habitual?",
    "Do you scroll between sets?": "¿Miras el teléfono entre series?",
    "How much of each break is scrolling?": "¿Cuánto del descanso pasas mirando contenidos?",
    "Your time at the gym.": "Tu tiempo en el gimnasio.",
    "Ready for your next set.": "Listo para tu próxima serie.",
    "Get started": "Empezar",
    "Just train": "Entrenar ahora",
    "workouts / week": "entrenamientos / semana",
    "Visit minutes": "Minutos por visita",
    "Sets each": "Series por ejercicio",
    "Varies": "Varía",
    "Mostly timed": "Principalmente por tiempo",
    "Use reps": "Usar repeticiones",
    "Assuming every break": "Suponiendo cada descanso",
    "Edit": "Editar",
    "Show me": "Muéstrame",
    "scrolling breaks": "descansos con teléfono",
    "Scrolling breaks": "Descansos con teléfono",
    "scrolling minutes per workout": "minutos con teléfono por entrenamiento",
    "more phone-free minutes": "más minutos sin teléfono",
    "Based on your answers": "Según tus respuestas",
    "If you halve scrolling between sets.": "Si reduces a la mitad el uso entre series.",
    "If you skip scrolling between sets.": "Si dejas de mirar contenidos entre series.",
    "Half as much": "La mitad",
    "No scrolling": "Sin distracciones",
    "min across": "min en",
    "weekly workouts": "entrenamientos semanales",
    "How this is estimated": "Cómo lo estimamos",
    "See the difference": "Ver la diferencia",
    "Use this goal": "Elegir este objetivo",
    "Continue without a goal": "Continuar sin objetivo",
    "Go to Home": "Ir a Inicio",
    "See one set": "Ver una serie",
    "Check the number of scrolling breaks.": "Revisa el número de descansos con teléfono.",
    "That exceeds your visit. Check your answers.": "Supera tu visita. Revisa tus respuestas.",
    "Edit time": "Editar tiempo",
    "Edit routine": "Editar entrenamiento",
    "Edit scrolling breaks": "Editar descansos con teléfono",
    "Phone-free time includes rest. This is an estimate, not measured phone use.":
      "El tiempo sin teléfono incluye descanso. Es una estimación, no una medición.",
    "Possible change": "Cambio posible",
    "minute visit": "minutos por visita",
    "Phone-free": "Sin teléfono",
    "Scrolling": "Con teléfono",
    "Setup progress": "Progreso de configuración",
    "Options": "Opciones",
    "Enable haptics": "Activar respuesta háptica",
    "Mute haptics": "Desactivar respuesta háptica",
    "Tap to edit": "Toca para editar",
    "Use every break": "Usar todos los descansos",
    "Apps you tend to scroll": "Contenidos que sueles mirar",
    "Social feeds": "Redes sociales",
    "Start again": "Volver a empezar",
    "Stop set": "Terminar serie",
    "Example": "Ejemplo",
    "Focus demo": "Demo de concentración",
  ]
  static let additions: [String: String] = [
    "Training totals": "Totales de entrenamiento",
    "All workouts": "Todos los entrenamientos",
    "View": "Vista",
    "Trend": "Tendencia",
    "Bars": "Barras",
    "Metric": "Métrica",
    "Weight moved": "Peso movido",
    "Across": "En",
    "workouts": "entrenamientos",
    "moved": "movidos",
    "No rep-based workouts yet.": "Aún no hay entrenamientos con repeticiones.",
    "Work performed, not a strength score. Completed sets include warm-ups; timed activities are separate.":
      "Trabajo realizado, no una puntuación de fuerza. Incluye series de calentamiento; las actividades por tiempo son independientes.",
    "Sum of logged load × completed reps. Bodyweight adds no guessed load. Dumbbell load uses your per-dumbbell entry.":
      "Suma de carga registrada × repeticiones completadas. No se estima carga corporal. La carga de mancuerna usa tu valor por mancuerna.",
    "Workout values": "Valores por entrenamiento",
    "Sounds": "Sonidos",
    "Haptics": "Respuesta háptica",
    "Mute sounds": "Silenciar sonidos",
    "Enable sounds": "Activar sonidos",
    "Yes": "Sí",
    "No": "No",
    "More": "Más",
    "Minutes per break": "Minutos por descanso",
    "breaks": "descansos",
    "min per break": "min por descanso",
    "Do you scroll through your phone in between sets?":
      "¿Miras contenidos en el teléfono entre series?",
    "How many minutes between each set?": "¿Cuántos minutos entre cada serie?",
    "Assumes you scroll during every break, including between exercises.":
      "Supone que miras contenidos en cada descanso, incluso entre ejercicios.",
    "Add your usual exercise and set counts to estimate time.":
      "Añade tus cantidades habituales de ejercicios y series para estimar el tiempo.",
    "Assumes scrolling in every break. This is your estimate, not measured phone use.":
      "Supone uso del teléfono en cada descanso. Es tu estimación, no una medición.",
    "Enter 1–600 minutes per break, or leave it blank.":
      "Introduce entre 1 y 600 minutos por descanso o déjalo vacío.",
    "Estimated scrolling exceeds your visit. Check minutes per break or your routine.":
      "El tiempo estimado supera tu visita. Revisa los minutos por descanso o tu rutina.",
    "Home": "Inicio", "Workouts": "Entrenamientos", "History view": "Vista del historial",
    "workouts saved": "entrenamientos guardados", "Split progress": "Progreso de rutina",
    "Choose exercises as you go": "Elige ejercicios sobre la marcha",
    "Resume workout": "Volver al entrenamiento",
    "Rest elapsed": "Descanso transcurrido", "This workout": "Este entrenamiento",
    "Switch exercise?": "¿Cambiar de ejercicio?", "Save set and switch": "Guardar serie y cambiar",
    "Discard current set and switch": "Descartar serie actual y cambiar",
    "Completed sets stay saved. Choose what to do with this unfinished set.":
      "Las series completadas siguen guardadas. Elige qué hacer con esta serie sin terminar.",
    "Good morning": "Buenos días", "Good afternoon": "Buenas tardes",
    "Good evening": "Buenas noches",
    "Your workout": "Tu entrenamiento", "Week streak": "Semanas seguidas",
    "exercises": "ejercicios",
    "Settings": "Ajustes", "Splits": "Rutinas", "Split": "Rutina",
    "Split name": "Nombre de la rutina", "Add split": "Añadir rutina",
    "Edit split": "Editar rutina", "Save": "Guardar",
    "Start workout": "Iniciar entrenamiento", "Workout": "Entrenamiento",
    "Free workout": "Entrenamiento libre", "Biggest lifts": "Mayores levantamientos",
    "Progress": "Progreso",
    "Blocking is simulated in this prototype.": "El bloqueo es simulado en este prototipo.",
    "Your lift records appear after your first workout.":
      "Tus récords aparecen después del primer entrenamiento.",
    "Heaviest logged sets. Reps shown alongside.": "Series con mayor peso y sus repeticiones.",
    "Sample history loaded · new workouts save normally":
      "Historial de ejemplo · los nuevos entrenamientos se guardan",
    "Your preferences": "Tus preferencias",
    "Load sample workouts": "Cargar entrenamientos de ejemplo", "Exercises": "Ejercicios",
    "Add exercises": "Añadir ejercicios",
    "Splits are optional. You can always start a free workout.":
      "Las rutinas son opcionales. Siempre puedes entrenar libremente.",
    "Use a unique name and add at least one exercise.":
      "Usa un nombre único y añade al menos un ejercicio.",
    "Add a split in Settings to track its progress.":
      "Añade una rutina en Ajustes para seguir su progreso.",
    "No sets logged yet.": "Aún no hay series registradas.",
    "Only workouts started from this split are shown.":
      "Solo se muestran entrenamientos iniciados desde esta rutina.",
    "Best weight at": "Mejor peso con", "First session": "Primera sesión",
    "Latest session": "Última sesión", "same reps": "mismas repeticiones",
    "Your baseline. Log another session to compare.":
      "Tu punto de partida. Registra otra sesión para comparar.",
    "Replay progress": "Repetir progreso", "Session date": "Fecha de la sesión",
    "Weight history at the same rep count": "Historial de peso con las mismas repeticiones",
    "Same exercise and reps, across sessions in this split.":
      "Mismo ejercicio y repeticiones en esta rutina.",
    "Latest activity duration": "Duración de la última actividad",
    "Choose an exercise": "Elige un ejercicio", "Search exercises": "Buscar ejercicios",
    "Recent & favorites": "Recientes y favoritos", "This split": "Esta rutina",
    "No matches. Add your own exercise below.": "Sin resultados. Añade tu propio ejercicio.",
    "Search to add an exercise outside this split.":
      "Busca para añadir un ejercicio fuera de esta rutina.",
    "Reps": "Repeticiones", "Logged sets": "Series registradas", "Last set": "Última serie",
    "Tap the number to type. Use the picker or + / − to adjust.":
      "Toca el número para escribir. Ajusta con el selector o + / −.",
    "Enter a weight from 0 to 500.": "Introduce un peso entre 0 y 500.",
    "Finish activity": "Terminar actividad", "Finish set": "Terminar serie",
    "Start next set": "Iniciar siguiente serie", "Workout complete": "Entrenamiento completo",
    "Save these exercises as a split": "Guardar estos ejercicios como rutina",
    "Dumbbell curl": "Curl con mancuerna", "Dumbbell hammer curl": "Curl martillo",
    "Incline dumbbell curl": "Curl inclinado",
    "Dumbbell bench press": "Press de banca con mancuernas",
    "Dumbbell shoulder press": "Press de hombros con mancuernas",
    "Dumbbell lateral raise": "Elevación lateral",
  ]
  static let words: [String: String] = [
    "Continue": "Continuar", "Back": "Atrás", "Your name": "Tu nombre",
    "What should we call you?": "¿Cómo te llamas?",
    "A little more you.": "Un poco más tú.",
    "Just a name. No account needed.": "Solo un nombre. Sin cuentas.",
    "Your training": "Tu entrenamiento", "How do you like to move?": "¿Cómo te gusta moverte?",
    "Pick as many as you like.": "Elige los que quieras.",
    "Cardio": "Cardio", "Weightlifting": "Pesas", "Stretching": "Estiramientos",
    "Compound movements": "Movimientos compuestos", "Martial arts": "Artes marciales",
    "Your favorites": "Tus favoritos", "The moves you love.": "Tus ejercicios favoritos.",
    "Pick a few. They'll be ready for your first workout.":
      "Elige algunos para tu primer entrenamiento.",
    "Arms": "Brazos", "Chest & shoulders": "Pecho y hombros", "Back & lats": "Espalda",
    "Legs & compound": "Piernas y compuestos", "Core": "Abdominales",
    "Biceps curl": "Curl de bíceps", "Triceps extension": "Extensión de tríceps",
    "Bench press": "Press de banca", "Shoulder press": "Press de hombros",
    "Dumbbell row": "Remo con mancuerna", "Lat pulldown": "Jalón al pecho", "Squat": "Sentadilla",
    "Deadlift": "Peso muerto", "Lunge": "Zancada", "Crunch": "Abdominal", "Running": "Correr",
    "Cycling": "Ciclismo", "Full-body stretch": "Estiramiento completo", "Boxing": "Boxeo",
    "Your focus": "Tu concentración", "Less scroll. More strength.": "Menos pantalla. Más fuerza.",
    "Choose what goes quiet during a session.": "Elige qué silenciar durante la sesión.",
    "Whole phone": "Todo el teléfono", "Everything except GymBlock": "Todo excepto GymBlock",
    "Selected apps": "Aplicaciones elegidas",
    "Only the distractions you choose": "Solo tus distracciones",
    "SIMULATOR PREVIEW": "VISTA DEL SIMULADOR",
    "Blocking is simulated. This prototype cannot restrict your phone or other apps.":
      "El bloqueo es simulado. Este prototipo no restringe el teléfono ni otras apps.",
    "Make room for your workout.": "Haz espacio para entrenar.",
    "Your focus, your workouts, your progress. One simple place.":
      "Concentración, entrenamientos y progreso. En un solo lugar.", "Annual": "Anual",
    "Monthly": "Mensual", "Placeholder prices · USD": "Precios de ejemplo · USD",
    "Enter prototype": "Entrar al prototipo",
    "No payment. No trial. No charge.": "Sin pago. Sin prueba. Sin cargos.",
    "Unlimited sessions": "Sesiones ilimitadas", "Simple workout logging": "Registro sencillo",
    "A little consistency, every week": "Constancia cada semana",
    "TODAY": "HOY", "Make this time yours.": "Este tiempo es tuyo.",
    "Start session": "Iniciar sesión",
    "Put distractions aside. Pick your workout next.":
      "Deja las distracciones. Luego elige tu entrenamiento.", "This week": "Esta semana",
    "training days": "días entrenados", "Last workout": "Último entrenamiento",
    "Your first workout starts here.": "Tu primer entrenamiento empieza aquí.",
    "A small start still counts.": "Un pequeño comienzo cuenta.",
    "Saved workouts": "Rutinas guardadas", "My favorites": "Mis favoritos",
    "Preferences": "Preferencias",
    "Local only. Just you and your workout.": "Solo en el dispositivo. Tú y tu entrenamiento.",
    "Focus preview on": "Simulación de bloqueo activa",
    "Focus preview ended": "Simulación finalizada", "Finish": "Terminar",
    "Choose your workout.": "Elige tu entrenamiento.",
    "The focus preview is already on.": "La simulación ya está activa.",
    "Custom workout": "Entrenamiento libre", "Build it as you go": "Constrúyelo sobre la marcha",
    "Choose an exercise.": "Elige un ejercicio.", "One move at a time.": "Un ejercicio a la vez.",
    "Workout name": "Nombre de la rutina", "My workout": "Mi entrenamiento",
    "Add custom exercise": "Añadir ejercicio", "Exercise name": "Nombre del ejercicio",
    "Duration-based": "Por duración", "Add exercise": "Añadir ejercicio", "Cancel": "Cancelar",
    "Ready when you are.": "Cuando quieras.", "Weight": "Peso",
    "Use 0 for bodyweight or no added weight.": "Usa 0 para ejercicios sin peso adicional.",
    "Start set": "Iniciar serie", "Start activity": "Iniciar actividad",
    "Your time to move.": "Tu momento de moverte.", "Set in progress": "Serie en curso",
    "Activity in progress": "Actividad en curso", "Complete set": "Completar serie",
    "Complete activity": "Completar actividad", "How did it go?": "¿Cómo fue?",
    "Reps completed": "Repeticiones realizadas", "Minutes completed": "Minutos realizados",
    "Log set": "Guardar serie", "Log activity": "Guardar actividad",
    "Enter a positive number to continue.": "Introduce un número positivo.",
    "Take a breath.": "Respira.", "Ready for another set?": "¿Otra serie?",
    "Ready to go again?": "¿Lo repetimos?",
    "Rest is part of the workout.": "Descansar es parte del entrenamiento.",
    "Optional rest timer": "Temporizador opcional", "Skip timer": "Omitir temporizador",
    "Another set": "Otra serie", "Repeat activity": "Repetir actividad",
    "Change exercise": "Cambiar ejercicio", "Logged this session": "Registro de esta sesión",
    "sets": "series", "reps": "repeticiones", "min": "min",
    "You showed up.": "Lo has conseguido.",
    "Workout saved on this device.": "Entrenamiento guardado en el dispositivo.",
    "Session ended.": "Sesión finalizada.",
    "No sets logged this time.": "No has registrado series.",
    "Save as a workout": "Guardar como rutina",
    "Use these exercises next time.": "Usa estos ejercicios la próxima vez.", "Done": "Listo",
    "Finish this session?": "¿Terminar esta sesión?",
    "Only logged sets will be saved. The focus preview will end.":
      "Solo se guardarán las series registradas. La simulación terminará.",
    "Keep training": "Seguir entrenando", "Weight unit": "Unidad de peso", "Language": "Idioma",
    "Name": "Nombre", "Focus choice": "Tipo de bloqueo",
    "Your data stays on this device. No account, cloud, or analytics.":
      "Tus datos se quedan aquí. Sin cuentas, nube ni analíticas.",
    "Rest complete": "Descanso terminado",
    "Good work. Go at your pace.": "Buen trabajo. Sigue a tu ritmo.",
    "Choose at least one app.": "Elige al menos una app.",
    "Enter a valid weight (0 or more).": "Introduce un peso válido (0 o más).",
    "Keep it simple.": "Todo sencillo.", "Edit favorites": "Editar favoritos",
    "exercises": "ejercicios", "Focus": "Concentración", "History": "Historial",
    "No workouts yet.": "Aún no hay entrenamientos.", "Rest": "Descanso",
    "Saved locally": "Guardado localmente",
  ]
}

extension Spanish {
  static let redesign: [String: String] = [
    "Enter completed minutes above zero.": "Introduce los minutos realizados, mayores que cero.",
    "Custom goal": "Objetivo personalizado",
    "Fewer feed minutes per workout": "Menos minutos en redes por entrenamiento",
    "Previous workout": "Entrenamiento anterior",
    "Latest workout": "Último entrenamiento",
    "Different weight or reps": "Peso o repeticiones diferentes",
    "Choose weight": "Elegir peso",
    "Remove extra exercise answers?": "¿Eliminar respuestas de ejercicios adicionales?",
    "Remove extra answers": "Eliminar respuestas adicionales",
    "Keep answers": "Conservar respuestas",
    "Your workout deserves your attention.": "Tu entrenamiento merece tu atención.",
    "A quick scroll can become a long break. Keep your attention on the next rep.":
      "Un vistazo al móvil puede convertirse en una larga pausa. Concéntrate en la siguiente repetición.",
    "Optional. No account needed.": "Opcional. No necesitas una cuenta.",
    "Where do you get caught scrolling?": "¿Dónde te quedas deslizando?",
    "Short videos": "Vídeos cortos",
    "Social feeds": "Redes sociales",
    "Video platforms": "Plataformas de vídeo",
    "News & forums": "Noticias y foros",
    "Other": "Otra",
    "None": "Ninguna",
    "Not sure": "No lo sé",
    "How long is a usual gym visit?": "¿Cuánto dura normalmente tu entrenamiento?",
    "From starting your workout to finishing.": "Desde el inicio hasta el final del entrenamiento.",
    "Minutes": "Minutos",
    "Workouts per week": "Entrenamientos por semana",
    "What does a usual workout look like?": "¿Cómo es tu entrenamiento habitual?",
    "Mostly timed exercise": "Principalmente ejercicios por tiempo",
    "Sets per exercise": "Series por ejercicio",
    "Reps per set": "Repeticiones por serie",
    "Count or range · 8–12": "Cantidad o intervalo · 8–12",
    "Varies": "Varía",
    "Different for each exercise?": "¿Es diferente para cada ejercicio?",
    "Individual exercise answers saved": "Respuestas por ejercicio guardadas",
    "How much of that visit goes to scrolling?": "¿Cuánto tiempo pasas mirando contenido?",
    "Think feeds and videos, not music or logging sets.":
      "Piensa en redes y vídeos, no en música o registrar series.",
    "Minutes on feeds": "Minutos en redes",
    "Make more room for your workout.": "Haz espacio para tu entrenamiento.",
    "Keep your workout simple.": "Entrena de forma sencilla.",
    "min/week on feeds": "min/semana en redes",
    "Based on your estimate:": "Según tu estimación:",
    "min/workout": "min/entrenamiento",
    "min/workout on feeds": "min/entrenamiento en redes",
    "Find your rhythm over your next few workouts.":
      "Encuentra tu ritmo en los próximos entrenamientos.",
    "Your routine": "Tu rutina",
    "Keep the rest you need. Leave the feed for later.":
      "Descansa lo que necesites. Deja las redes para después.",
    "fewer feed minutes per workout": "minutos menos en redes por entrenamiento",
    "No goal": "Sin objetivo",
    "Goal:": "Objetivo:",
    "Choose a goal": "Elegir un objetivo",
    "Why focus?": "¿Por qué concentrarte?",
    "Keep your attention on the movement and the muscle you're working. This demo previews focus mode; it doesn't measure attention or predict muscle gain.":
      "Concéntrate en el movimiento y en el músculo que trabajas. Esta demo muestra el modo de concentración; no mide la atención ni predice ganancias musculares.",
    "Try workout focus": "Prueba la concentración",
    "This demo previews focus mode. It doesn't block other apps.":
      "Esta demo muestra el modo de concentración. No bloquea otras apps.",
    "You can end your workout whenever you need to.":
      "Puedes terminar tu entrenamiento cuando lo necesites.",
    "Set up focus": "Configurar concentración",
    "Try demo": "Probar demo",
    "Start without blocking": "Empezar sin bloqueo",
    "Skip setup": "Omitir configuración",
    "About": "Aproximadamente",
    "sets/workout": "series/entrenamiento",
    "estimated reps/workout": "repeticiones estimadas/entrenamiento",
    "gym min/week": "min de gimnasio/semana",
    "Not supplied": "Sin respuesta",
    "Exercise name (optional)": "Nombre del ejercicio (opcional)",
    "Sets": "Series",
    "Reps · 8–12 or 12,10,8": "Repeticiones · 8–12 o 12,10,8",
    "Use typical values instead": "Usar valores habituales",
    "Each exercise": "Cada ejercicio",
    "Enter 1–600 minutes, or leave it blank.": "Introduce 1–600 minutos o déjalo vacío.",
    "Enter 0–21 visits, or leave it blank.": "Introduce 0–21 visitas o déjalo vacío.",
    "Enter 1–50 exercises, or leave it blank.": "Introduce 1–50 ejercicios o déjalo vacío.",
    "Enter 1–50 sets, or leave it blank.": "Introduce 1–50 series o déjalo vacío.",
    "Use a rep count or range, such as 8–12.": "Usa una cantidad o un intervalo, como 8–12.",
    "Enter 0–600 minutes, or leave it blank.": "Introduce 0–600 minutos o déjalo vacío.",
    "Scrolling time exceeds your visit. Edit either answer.":
      "El tiempo en redes supera tu visita. Corrige una respuesta.",
    "Manage splits": "Gestionar rutinas",
    "Best lifts": "Mejores levantamientos",
    "Your best lifts will appear here.": "Tus mejores levantamientos aparecerán aquí.",
    "Demo": "Demo",
    "A week counts when you finish at least one set. Rest days don't break your streak.":
      "Una semana cuenta cuando terminas al menos una serie. Los días de descanso no rompen la racha.",
    "Consistency": "Constancia",
    "Edit routine answers": "Editar respuestas de rutina",
    "Name (optional)": "Nombre (opcional)",
    "Focus demo": "Concentración demo",
    "Focus off": "Concentración desactivada",
    "This demo doesn't block other apps.": "Esta demo no bloquea otras apps.",
    "Delete routine answers": "Eliminar respuestas de rutina",
    "Saved on this device. No account or analytics.":
      "Guardado en este dispositivo. Sin cuenta ni analíticas.",
    "Delete routine answers?": "¿Eliminar respuestas de rutina?",
    "Delete": "Eliminar",
    "Your workouts and splits will stay saved.": "Tus entrenamientos y rutinas seguirán guardados.",
    "Attempt": "Intento",
    "Warm-up": "Calentamiento",
    "Undo delete": "Deshacer eliminación",
    "Cancel set": "Cancelar serie",
    "Record unsuccessful attempt": "Registrar intento no completado",
    "End workout": "Terminar entrenamiento",
    "Workout options": "Opciones de entrenamiento",
    "End workout?": "¿Terminar entrenamiento?",
    "Save set and end": "Guardar serie y terminar",
    "Discard current set and end": "Descartar serie actual y terminar",
    "Bodyweight": "Peso corporal",
    "Minutes completed (optional correction)": "Minutos realizados (corrección opcional)",
    "Decrease reps": "Reducir repeticiones",
    "Increase reps": "Aumentar repeticiones",
    "Enter completed reps, or record an attempt from Workout options.":
      "Introduce las repeticiones realizadas o registra un intento desde las opciones.",
    "Ready": "Listo",
    "Edit rest timer": "Editar descanso",
    "Saved:": "Guardado:",
    "Next set": "Siguiente serie",
    "Edit weight": "Editar peso",
    "Per dumbbell · reps per side": "Por mancuerna · repeticiones por lado",
    "Last time:": "Última vez:",
    "Recent exercises": "Ejercicios recientes",
    "Results": "Resultados",
    "Decrease weight": "Reducir peso",
    "Increase weight": "Aumentar peso",
    "Rest duration": "Duración del descanso",
    "Add completed set": "Añadir serie realizada",
    "Unsuccessful attempt · 0 completed reps": "Intento no completado · 0 repeticiones",
    "Completed at": "Realizado a las",
    "Check the entered values.": "Revisa los valores introducidos.",
    "Delete set": "Eliminar serie",
    "Edit set": "Editar serie",
    "Workout saved": "Entrenamiento guardado",
    "Attempt recorded": "Intento registrado",
    "Focus demo ended": "Concentración demo finalizada",
    "Save as split": "Guardar como rutina",
    "View workout": "Ver entrenamiento",
    "Next:": "Siguiente:",
    "Set": "Serie",
    "Add a split to compare its exercises.": "Añade una rutina para comparar sus ejercicios.",
    "Same weight:": "Mismo peso:",
    "Same reps:": "Mismas repeticiones:",
    "Compare": "Comparar",
    "First": "Primera",
    "Latest": "Última",
    "First recorded set": "Primera serie registrada",
    "No comparable sets yet.": "Aún no hay series comparables.",
    "Comparable workout history": "Historial de entrenamientos comparables",
  ]
}
