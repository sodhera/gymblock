import Foundation

// The built-in exercise library. Hand-curated to the lifts people actually do,
// named the way lifters say them ("Bench Press (Barbell)"). Muscle mappings
// follow the usual primary/secondary conventions and drive the muscle-map
// icons (`MuscleMapIcon`). Users add their own with `Exercise.isCustom`.
//
// IDs are stable forever — they are stored in every workout and template.
// Rename freely; never change an id.

enum ExerciseCatalog {
    static let all: [Exercise] = chest + back + shoulders + arms + legs + core + fullBody + cardio

    static let byID: [String: Exercise] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    private static func e(
        _ id: String, _ name: String, _ equipment: Equipment, _ primary: [Muscle], _ secondary: [Muscle] = [],
        _ metric: MetricKind = .weightReps
    ) -> Exercise {
        Exercise(id: id, name: name, equipment: equipment, primary: primary, secondary: secondary, metric: metric)
    }

    static let chest: [Exercise] = [
        e("bench-press-bb", "Bench Press", .barbell, [.chest], [.triceps, .shoulders]),
        e("bench-press-db", "Bench Press", .dumbbell, [.chest], [.triceps, .shoulders]),
        e("bench-press-smith", "Bench Press", .smith, [.chest], [.triceps, .shoulders]),
        e("incline-bench-bb", "Incline Bench Press", .barbell, [.chest], [.shoulders, .triceps]),
        e("incline-bench-db", "Incline Bench Press", .dumbbell, [.chest], [.shoulders, .triceps]),
        e("incline-bench-smith", "Incline Bench Press", .smith, [.chest], [.shoulders, .triceps]),
        e("decline-bench-bb", "Decline Bench Press", .barbell, [.chest], [.triceps]),
        e("chest-press-machine", "Chest Press", .machine, [.chest], [.triceps, .shoulders]),
        e("incline-chest-press-machine", "Incline Chest Press", .machine, [.chest], [.shoulders, .triceps]),
        e("chest-fly-db", "Chest Fly", .dumbbell, [.chest], [.shoulders]),
        e("incline-fly-db", "Incline Chest Fly", .dumbbell, [.chest], [.shoulders]),
        e("pec-deck", "Pec Deck", .machine, [.chest], [.shoulders]),
        e("cable-fly", "Cable Fly Crossover", .cable, [.chest], [.shoulders]),
        e("low-cable-fly", "Low to High Cable Fly", .cable, [.chest], [.shoulders]),
        e("push-up", "Push Up", .bodyweight, [.chest], [.triceps, .shoulders], .reps),
        e("chest-dip", "Chest Dip", .bodyweight, [.chest], [.triceps, .shoulders], .reps),
        e("floor-press-db", "Floor Press", .dumbbell, [.chest], [.triceps]),
    ]

    static let back: [Exercise] = [
        e("deadlift-bb", "Deadlift", .barbell, [.lowerBack, .hamstrings, .glutes], [.traps, .forearms, .quads]),
        e("pull-up", "Pull Up", .bodyweight, [.lats], [.biceps, .upperBack], .reps),
        e("chin-up", "Chin Up", .bodyweight, [.lats, .biceps], [.upperBack], .reps),
        e("pull-up-weighted", "Weighted Pull Up", .plate, [.lats], [.biceps, .upperBack]),
        e("assisted-pull-up", "Assisted Pull Up", .machine, [.lats], [.biceps]),
        e("lat-pulldown-cable", "Lat Pulldown", .cable, [.lats], [.biceps, .upperBack]),
        e("lat-pulldown-close", "Close Grip Lat Pulldown", .cable, [.lats], [.biceps]),
        e("lat-pulldown-machine", "Lat Pulldown", .machine, [.lats], [.biceps]),
        e("straight-arm-pulldown", "Straight Arm Pulldown", .cable, [.lats], [.triceps]),
        e("bent-over-row-bb", "Bent Over Row", .barbell, [.upperBack, .lats], [.biceps, .lowerBack]),
        e("pendlay-row", "Pendlay Row", .barbell, [.upperBack, .lats], [.biceps]),
        e("row-db", "Dumbbell Row", .dumbbell, [.lats, .upperBack], [.biceps]),
        e("chest-supported-row-db", "Chest Supported Row", .dumbbell, [.upperBack], [.lats, .biceps]),
        e("seated-row-cable", "Seated Cable Row", .cable, [.upperBack, .lats], [.biceps]),
        e("seated-row-machine", "Seated Row", .machine, [.upperBack, .lats], [.biceps]),
        e("t-bar-row", "T-Bar Row", .barbell, [.upperBack, .lats], [.biceps]),
        e("face-pull", "Face Pull", .cable, [.shoulders, .upperBack], [.traps]),
        e("shrug-bb", "Shrug", .barbell, [.traps]),
        e("shrug-db", "Shrug", .dumbbell, [.traps]),
        e("back-extension", "Back Extension", .bodyweight, [.lowerBack], [.glutes, .hamstrings], .reps),
        e("good-morning", "Good Morning", .barbell, [.hamstrings, .lowerBack], [.glutes]),
        e("rack-pull", "Rack Pull", .barbell, [.lowerBack, .traps], [.glutes, .hamstrings]),
        e("inverted-row", "Inverted Row", .bodyweight, [.upperBack], [.lats, .biceps], .reps),
    ]

    static let shoulders: [Exercise] = [
        e("ohp-bb", "Overhead Press", .barbell, [.shoulders], [.triceps, .upperBack]),
        e("shoulder-press-db", "Shoulder Press", .dumbbell, [.shoulders], [.triceps]),
        e("shoulder-press-machine", "Shoulder Press", .machine, [.shoulders], [.triceps]),
        e("arnold-press", "Arnold Press", .dumbbell, [.shoulders], [.triceps]),
        e("push-press", "Push Press", .barbell, [.shoulders], [.triceps, .quads]),
        e("lateral-raise-db", "Lateral Raise", .dumbbell, [.shoulders]),
        e("lateral-raise-cable", "Lateral Raise", .cable, [.shoulders]),
        e("lateral-raise-machine", "Lateral Raise", .machine, [.shoulders]),
        e("front-raise-db", "Front Raise", .dumbbell, [.shoulders]),
        e("rear-delt-fly-db", "Rear Delt Fly", .dumbbell, [.shoulders], [.upperBack]),
        e("reverse-pec-deck", "Reverse Fly", .machine, [.shoulders], [.upperBack]),
        e("upright-row", "Upright Row", .barbell, [.shoulders, .traps], [.biceps]),
    ]

    static let arms: [Exercise] = [
        e("curl-bb", "Bicep Curl", .barbell, [.biceps], [.forearms]),
        e("curl-db", "Bicep Curl", .dumbbell, [.biceps], [.forearms]),
        e("curl-ez", "Bicep Curl", .ezBar, [.biceps], [.forearms]),
        e("curl-cable", "Bicep Curl", .cable, [.biceps], [.forearms]),
        e("hammer-curl", "Hammer Curl", .dumbbell, [.biceps, .forearms]),
        e("incline-curl", "Incline Curl", .dumbbell, [.biceps]),
        e("preacher-curl-ez", "Preacher Curl", .ezBar, [.biceps]),
        e("preacher-curl-machine", "Preacher Curl", .machine, [.biceps]),
        e("concentration-curl", "Concentration Curl", .dumbbell, [.biceps]),
        e("spider-curl", "Spider Curl", .dumbbell, [.biceps]),
        e("triceps-pushdown", "Triceps Pushdown", .cable, [.triceps]),
        e("triceps-rope-pushdown", "Triceps Rope Pushdown", .cable, [.triceps]),
        e("overhead-triceps-cable", "Overhead Triceps Extension", .cable, [.triceps]),
        e("overhead-triceps-db", "Overhead Triceps Extension", .dumbbell, [.triceps]),
        e("skullcrusher-ez", "Skullcrusher", .ezBar, [.triceps]),
        e("skullcrusher-db", "Skullcrusher", .dumbbell, [.triceps]),
        e("close-grip-bench", "Close Grip Bench Press", .barbell, [.triceps], [.chest]),
        e("triceps-dip", "Triceps Dip", .bodyweight, [.triceps], [.chest, .shoulders], .reps),
        e("triceps-kickback", "Triceps Kickback", .dumbbell, [.triceps]),
        e("wrist-curl", "Wrist Curl", .dumbbell, [.forearms]),
        e("reverse-curl", "Reverse Curl", .ezBar, [.forearms], [.biceps]),
    ]

    static let legs: [Exercise] = [
        e("squat-bb", "Squat", .barbell, [.quads, .glutes], [.hamstrings, .lowerBack]),
        e("front-squat", "Front Squat", .barbell, [.quads], [.glutes, .abs]),
        e("squat-smith", "Squat", .smith, [.quads, .glutes], [.hamstrings]),
        e("goblet-squat", "Goblet Squat", .dumbbell, [.quads, .glutes], [.abs]),
        e("hack-squat", "Hack Squat", .machine, [.quads], [.glutes]),
        e("leg-press", "Leg Press", .machine, [.quads, .glutes], [.hamstrings]),
        e("bulgarian-split-squat", "Bulgarian Split Squat", .dumbbell, [.quads, .glutes], [.hamstrings]),
        e("lunge-db", "Lunge", .dumbbell, [.quads, .glutes], [.hamstrings]),
        e("walking-lunge", "Walking Lunge", .dumbbell, [.quads, .glutes], [.hamstrings]),
        e("step-up", "Step Up", .dumbbell, [.quads, .glutes]),
        e("leg-extension", "Leg Extension", .machine, [.quads]),
        e("rdl-bb", "Romanian Deadlift", .barbell, [.hamstrings, .glutes], [.lowerBack]),
        e("rdl-db", "Romanian Deadlift", .dumbbell, [.hamstrings, .glutes], [.lowerBack]),
        e("stiff-leg-deadlift", "Stiff Leg Deadlift", .barbell, [.hamstrings], [.glutes, .lowerBack]),
        e("sumo-deadlift", "Sumo Deadlift", .barbell, [.glutes, .quads, .adductors], [.hamstrings, .lowerBack]),
        e("trap-bar-deadlift", "Trap Bar Deadlift", .other, [.quads, .glutes], [.hamstrings, .traps]),
        e("lying-leg-curl", "Lying Leg Curl", .machine, [.hamstrings]),
        e("seated-leg-curl", "Seated Leg Curl", .machine, [.hamstrings]),
        e("nordic-curl", "Nordic Curl", .bodyweight, [.hamstrings], [], .reps),
        e("hip-thrust-bb", "Hip Thrust", .barbell, [.glutes], [.hamstrings]),
        e("hip-thrust-machine", "Hip Thrust", .machine, [.glutes], [.hamstrings]),
        e("glute-bridge", "Glute Bridge", .bodyweight, [.glutes], [.hamstrings], .reps),
        e("cable-kickback", "Glute Kickback", .cable, [.glutes]),
        e("hip-abduction", "Hip Abduction", .machine, [.abductors], [.glutes]),
        e("hip-adduction", "Hip Adduction", .machine, [.adductors]),
        e("standing-calf-raise", "Standing Calf Raise", .machine, [.calves]),
        e("seated-calf-raise", "Seated Calf Raise", .machine, [.calves]),
        e("calf-press", "Calf Press", .machine, [.calves]),
        e("calf-raise-db", "Calf Raise", .dumbbell, [.calves]),
    ]

    static let core: [Exercise] = [
        e("plank", "Plank", .bodyweight, [.abs], [.obliques], .time),
        e("side-plank", "Side Plank", .bodyweight, [.obliques], [.abs], .time),
        e("crunch", "Crunch", .bodyweight, [.abs], [], .reps),
        e("cable-crunch", "Cable Crunch", .cable, [.abs]),
        e("hanging-leg-raise", "Hanging Leg Raise", .bodyweight, [.abs], [.obliques], .reps),
        e("lying-leg-raise", "Lying Leg Raise", .bodyweight, [.abs], [], .reps),
        e("ab-wheel", "Ab Wheel Rollout", .other, [.abs], [.lats], .reps),
        e("russian-twist", "Russian Twist", .bodyweight, [.obliques], [.abs], .reps),
        e("cable-woodchop", "Woodchopper", .cable, [.obliques], [.abs]),
        e("dead-bug", "Dead Bug", .bodyweight, [.abs], [], .reps),
        e("decline-crunch", "Decline Crunch", .bodyweight, [.abs], [], .reps),
        e("pallof-press", "Pallof Press", .cable, [.obliques, .abs]),
    ]

    static let fullBody: [Exercise] = [
        e("clean", "Power Clean", .barbell, [.fullBody], [.traps, .quads, .glutes]),
        e("clean-and-jerk", "Clean and Jerk", .barbell, [.fullBody], [.shoulders, .quads]),
        e("snatch", "Snatch", .barbell, [.fullBody], [.shoulders, .quads]),
        e("thruster", "Thruster", .barbell, [.quads, .shoulders], [.glutes, .triceps]),
        e("kb-swing", "Kettlebell Swing", .kettlebell, [.glutes, .hamstrings], [.lowerBack, .shoulders]),
        e("farmers-walk", "Farmer's Walk", .dumbbell, [.forearms, .traps], [.abs], .distanceTime),
        e("burpee", "Burpee", .bodyweight, [.fullBody], [.chest, .quads], .reps),
        e("sled-push", "Sled Push", .other, [.quads, .glutes], [.calves], .distanceTime),
    ]

    static let cardio: [Exercise] = [
        e("treadmill", "Treadmill", .machine, [.cardio], [.quads, .calves], .distanceTime),
        e("stairmaster", "Stair Climber", .machine, [.cardio], [.glutes, .quads], .time),
        e("rowing-machine", "Rowing Machine", .machine, [.cardio], [.lats, .quads], .distanceTime),
        e("cycling", "Stationary Bike", .machine, [.cardio], [.quads], .distanceTime),
        e("elliptical", "Elliptical", .machine, [.cardio], [.quads], .time),
        e("jump-rope", "Jump Rope", .other, [.cardio], [.calves], .time),
    ]
}
