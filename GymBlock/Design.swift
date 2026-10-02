import SwiftUI
import UIKit

enum GymColor {
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
    static let ground = adaptive(0xF5F6FA, 0x11141D)
    static let surface = adaptive(0xFFFFFF, 0x1C2230)
    static let ink = adaptive(0x16233D, 0xF2F4FA)
    static let dim = adaptive(0x59647A, 0xB1BCD0)
    static let red = adaptive(0xC62F42, 0xFF7D8D)
    static let blue = adaptive(0x2459BF, 0x91B5FF)
    static let action = Color(red: 0.14, green: 0.32, blue: 0.71)
    static let wash = adaptive(0xE8EEFD, 0x26334F)
}
struct GymButton: View {
    var title: String
    var icon: String? = nil
    var secondary = false
    var enabled = true
    var id: String = ""
    var finishSet = false
    var action: () -> Void
    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 10) {
                Text(title).font(.system(.headline, design: .default))
                if let icon { Image(systemName: icon) }
            }
            .frame(maxWidth: .infinity).frame(minHeight: 56)
            .foregroundStyle(secondary ? GymColor.ink : .white)
            .background(secondary ? GymColor.surface : (finishSet ? Color(red: 0.76, green: 0.15, blue: 0.23) : GymColor.action), in: RoundedRectangle(cornerRadius: 16))
            .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain).disabled(!enabled).accessibilityIdentifier(id)
    }
}
struct ChoiceRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var selected = false
    var id = ""
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 21, weight: .medium))
                        .frame(width: 40, height: 40)
                        .background(GymColor.wash.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(.body, design: .default, weight: .semibold))
                    if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(GymColor.dim) }
                }
                Spacer(minLength: 6)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23)).foregroundStyle(selected ? GymColor.blue : GymColor.dim.opacity(0.45))
            }
            .foregroundStyle(GymColor.ink).padding(16).frame(minHeight: 64)
            .background(selected ? GymColor.wash : GymColor.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? GymColor.red.opacity(0.65) : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct PageTitle: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow.uppercased()).font(.caption.weight(.bold)).tracking(2).foregroundStyle(GymColor.dim)
            Text(title).font(.system(.largeTitle, design: .default, weight: .bold)).tracking(-1)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.body).foregroundStyle(GymColor.dim).lineSpacing(3)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct GymMark: View {
    var size: CGFloat = 150
    var celebrate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        ZStack {
            Circle().fill(GymColor.wash).frame(width: size, height: size)
            Image(systemName: celebrate ? "checkmark" : "dumbbell.fill")
                .font(.system(size: size * 0.40, weight: .bold))
                .foregroundStyle(celebrate ? GymColor.blue : GymColor.red)
                .rotationEffect(.degrees(celebrate ? 0 : -28))
        }
        .scaleEffect(appeared ? 1 : 0.88)
        .animation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.6), value: appeared)
        .onAppear { appeared = true }.accessibilityHidden(true)
        .frame(width: size * 1.25, height: size * 1.25)
    }
}
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(GymColor.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}
struct NumberField: View {
    let label: String
    @Binding var text: String
    var decimal = false
    var id: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.subheadline.weight(.medium)).foregroundStyle(GymColor.dim)
            TextField("0", text: $text)
                .font(.system(size: 52, weight: .bold, design: .default)).monospacedDigit()
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .accessibilityLabel(label).accessibilityIdentifier(id)
                .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { notification in
                    guard let field = notification.object as? UITextField, field.isFirstResponder else { return }
                    DispatchQueue.main.async { field.selectAll(nil) }
                }
                .padding(.bottom, 8)
        }.padding(24).background(GymColor.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}
extension GymStore {
    func t(_ key: String) -> String { profile.language == "es" ? Spanish.additions[key] ?? Spanish.words[key] ?? key : key }
}
enum Spanish {
    static let additions: [String: String] = [
        "Settings": "Ajustes", "Splits": "Rutinas", "Split": "Rutina", "Split name": "Nombre de la rutina", "Add split": "Añadir rutina", "Edit split": "Editar rutina", "Save": "Guardar",
        "Start workout": "Iniciar entrenamiento", "Workout": "Entrenamiento", "Free workout": "Entrenamiento libre", "Biggest lifts": "Mayores levantamientos", "Progress": "Progreso",
        "Blocking is simulated in this prototype.": "El bloqueo es simulado en este prototipo.", "Your lift records appear after your first workout.": "Tus récords aparecen después del primer entrenamiento.",
        "Heaviest logged sets. Reps shown alongside.": "Series con mayor peso y sus repeticiones.", "Sample history loaded · new workouts save normally": "Historial de ejemplo · los nuevos entrenamientos se guardan",
        "Your preferences": "Tus preferencias", "Load sample workouts": "Cargar entrenamientos de ejemplo", "Exercises": "Ejercicios", "Add exercises": "Añadir ejercicios",
        "Splits are optional. You can always start a free workout.": "Las rutinas son opcionales. Siempre puedes entrenar libremente.", "Use a unique name and add at least one exercise.": "Usa un nombre único y añade al menos un ejercicio.",
        "Add a split in Settings to track its progress.": "Añade una rutina en Ajustes para seguir su progreso.", "No sets logged yet.": "Aún no hay series registradas.", "Only workouts started from this split are shown.": "Solo se muestran entrenamientos iniciados desde esta rutina.",
        "Best weight at": "Mejor peso con", "First session": "Primera sesión", "Latest session": "Última sesión", "same reps": "mismas repeticiones", "Your baseline. Log another session to compare.": "Tu punto de partida. Registra otra sesión para comparar.",
        "Replay progress": "Repetir progreso", "Session date": "Fecha de la sesión", "Weight history at the same rep count": "Historial de peso con las mismas repeticiones", "Same exercise and reps, across sessions in this split.": "Mismo ejercicio y repeticiones en esta rutina.", "Latest activity duration": "Duración de la última actividad",
        "Choose an exercise": "Elige un ejercicio", "Search exercises": "Buscar ejercicios", "Recent & favorites": "Recientes y favoritos", "This split": "Esta rutina", "No matches. Add your own exercise below.": "Sin resultados. Añade tu propio ejercicio.", "Search to add an exercise outside this split.": "Busca para añadir un ejercicio fuera de esta rutina.",
        "Reps": "Repeticiones", "Logged sets": "Series registradas", "Last set": "Última serie", "Tap the number to type. Use the picker or + / − to adjust.": "Toca el número para escribir. Ajusta con el selector o + / −.", "Enter a weight from 0 to 500.": "Introduce un peso entre 0 y 500.",
        "Finish activity": "Terminar actividad", "Finish set": "Terminar serie", "Start next set": "Iniciar siguiente serie", "Workout complete": "Entrenamiento completo", "Save these exercises as a split": "Guardar estos ejercicios como rutina",
        "Dumbbell curl": "Curl con mancuerna", "Dumbbell hammer curl": "Curl martillo", "Incline dumbbell curl": "Curl inclinado", "Dumbbell bench press": "Press de banca con mancuernas", "Dumbbell shoulder press": "Press de hombros con mancuernas", "Dumbbell lateral raise": "Elevación lateral"
    ]
    static let words: [String: String] = [
        "Continue": "Continuar", "Back": "Atrás", "Your name": "Tu nombre", "What should we call you?": "¿Cómo te llamas?",
        "A little more you.": "Un poco más tú.", "Just a name. No account needed.": "Solo un nombre. Sin cuentas.",
        "Your training": "Tu entrenamiento", "How do you like to move?": "¿Cómo te gusta moverte?", "Pick as many as you like.": "Elige los que quieras.",
        "Cardio": "Cardio", "Weightlifting": "Pesas", "Stretching": "Estiramientos", "Compound movements": "Movimientos compuestos", "Martial arts": "Artes marciales",
        "Your favorites": "Tus favoritos", "The moves you love.": "Tus ejercicios favoritos.", "Pick a few. They'll be ready for your first workout.": "Elige algunos para tu primer entrenamiento.",
        "Arms": "Brazos", "Chest & shoulders": "Pecho y hombros", "Back & lats": "Espalda", "Legs & compound": "Piernas y compuestos", "Core": "Abdominales",
        "Biceps curl": "Curl de bíceps", "Triceps extension": "Extensión de tríceps", "Bench press": "Press de banca", "Shoulder press": "Press de hombros", "Dumbbell row": "Remo con mancuerna", "Lat pulldown": "Jalón al pecho", "Squat": "Sentadilla", "Deadlift": "Peso muerto", "Lunge": "Zancada", "Crunch": "Abdominal", "Running": "Correr", "Cycling": "Ciclismo", "Full-body stretch": "Estiramiento completo", "Boxing": "Boxeo",
        "Your focus": "Tu concentración", "Less scroll. More strength.": "Menos pantalla. Más fuerza.", "Choose what goes quiet during a session.": "Elige qué silenciar durante la sesión.", "Whole phone": "Todo el teléfono", "Everything except GymBlock": "Todo excepto GymBlock", "Selected apps": "Aplicaciones elegidas", "Only the distractions you choose": "Solo tus distracciones", "SIMULATOR PREVIEW": "VISTA DEL SIMULADOR", "Blocking is simulated. This prototype cannot restrict your phone or other apps.": "El bloqueo es simulado. Este prototipo no restringe el teléfono ni otras apps.",
        "Make room for your workout.": "Haz espacio para entrenar.", "Your focus, your workouts, your progress. One simple place.": "Concentración, entrenamientos y progreso. En un solo lugar.", "Annual": "Anual", "Monthly": "Mensual", "Placeholder prices · USD": "Precios de ejemplo · USD", "Enter prototype": "Entrar al prototipo", "No payment. No trial. No charge.": "Sin pago. Sin prueba. Sin cargos.", "Unlimited sessions": "Sesiones ilimitadas", "Simple workout logging": "Registro sencillo", "A little consistency, every week": "Constancia cada semana",
        "TODAY": "HOY", "Make this time yours.": "Este tiempo es tuyo.", "Start session": "Iniciar sesión", "Put distractions aside. Pick your workout next.": "Deja las distracciones. Luego elige tu entrenamiento.", "This week": "Esta semana", "training days": "días entrenados", "Last workout": "Último entrenamiento", "Your first workout starts here.": "Tu primer entrenamiento empieza aquí.", "A small start still counts.": "Un pequeño comienzo cuenta.", "Saved workouts": "Rutinas guardadas", "My favorites": "Mis favoritos", "Preferences": "Preferencias", "Local only. Just you and your workout.": "Solo en el dispositivo. Tú y tu entrenamiento.",
        "Focus preview on": "Simulación de bloqueo activa", "Focus preview ended": "Simulación finalizada", "Finish": "Terminar", "Choose your workout.": "Elige tu entrenamiento.", "The focus preview is already on.": "La simulación ya está activa.", "Custom workout": "Entrenamiento libre", "Build it as you go": "Constrúyelo sobre la marcha", "Choose an exercise.": "Elige un ejercicio.", "One move at a time.": "Un ejercicio a la vez.", "Workout name": "Nombre de la rutina", "My workout": "Mi entrenamiento", "Add custom exercise": "Añadir ejercicio", "Exercise name": "Nombre del ejercicio", "Duration-based": "Por duración", "Add exercise": "Añadir ejercicio", "Cancel": "Cancelar",
        "Ready when you are.": "Cuando quieras.", "Weight": "Peso", "Use 0 for bodyweight or no added weight.": "Usa 0 para ejercicios sin peso adicional.", "Start set": "Iniciar serie", "Start activity": "Iniciar actividad", "Your time to move.": "Tu momento de moverte.", "Set in progress": "Serie en curso", "Activity in progress": "Actividad en curso", "Complete set": "Completar serie", "Complete activity": "Completar actividad", "How did it go?": "¿Cómo fue?", "Reps completed": "Repeticiones realizadas", "Minutes completed": "Minutos realizados", "Log set": "Guardar serie", "Log activity": "Guardar actividad", "Enter a positive number to continue.": "Introduce un número positivo.", "Take a breath.": "Respira.", "Ready for another set?": "¿Otra serie?", "Ready to go again?": "¿Lo repetimos?", "Rest is part of the workout.": "Descansar es parte del entrenamiento.", "Optional rest timer": "Temporizador opcional", "Skip timer": "Omitir temporizador", "Another set": "Otra serie", "Repeat activity": "Repetir actividad", "Change exercise": "Cambiar ejercicio", "Logged this session": "Registro de esta sesión", "sets": "series", "reps": "repeticiones", "min": "min",
        "You showed up.": "Lo has conseguido.", "Workout saved on this device.": "Entrenamiento guardado en el dispositivo.", "Session ended.": "Sesión finalizada.", "No sets logged this time.": "No has registrado series.", "Save as a workout": "Guardar como rutina", "Use these exercises next time.": "Usa estos ejercicios la próxima vez.", "Done": "Listo", "Finish this session?": "¿Terminar esta sesión?", "Only logged sets will be saved. The focus preview will end.": "Solo se guardarán las series registradas. La simulación terminará.", "Keep training": "Seguir entrenando", "Weight unit": "Unidad de peso", "Language": "Idioma", "Name": "Nombre", "Focus choice": "Tipo de bloqueo", "Your data stays on this device. No account, cloud, or analytics.": "Tus datos se quedan aquí. Sin cuentas, nube ni analíticas.", "Rest complete": "Descanso terminado", "Good work. Go at your pace.": "Buen trabajo. Sigue a tu ritmo.", "Choose at least one app.": "Elige al menos una app.", "Enter a valid weight (0 or more).": "Introduce un peso válido (0 o más).", "Keep it simple.": "Todo sencillo.", "Edit favorites": "Editar favoritos", "exercises": "ejercicios", "Focus": "Concentración", "History": "Historial", "No workouts yet.": "Aún no hay entrenamientos.", "Rest": "Descanso", "Saved locally": "Guardado localmente"
    ]
}
