// English and Dutch UI strings. Use t("key", {name: "Sam"}) to fill {placeholders}.

const STRINGS = {
  en: {
    "tab.today": "Today",
    "tab.group": "Group",
    "tab.history": "History",
    "tab.settings": "Settings",

    "onb.welcome.title": "Sleep without your phone",
    "onb.welcome.body": "Moonlight checks whether you used your phone during your night, and every morning shows how your group did.",
    "onb.start": "Get started",
    "onb.name": "Your name",
    "onb.name.hint": "As your group should see it",
    "onb.code": "Group code",
    "onb.code.hint": "Ask the organizer",
    "onb.goal": "Phone down by",
    "onb.goal.hint": "Your night window runs from this time until 07:00.",
    "onb.platform": "Your phone",
    "onb.continue": "Continue",
    "onb.err.name": "Enter your name",
    "onb.err.code": "That code doesn't match a group. Check it with the organizer.",
    "onb.setup.title": "One more step",
    "onb.setup.ios": "On iPhone, Moonlight measures with two Shortcuts automations. Your organizer sends you two shortcut files; the guide takes about 5 minutes.",
    "onb.setup.android": "On Android, install the Moonlight measuring app, allow usage access, and exempt it from battery saving.",
    "onb.setup.home": "Then add this page to your home screen, so it opens like an app.",
    "onb.done": "Done",

    "today.greeting.morning": "Good morning, {name}",
    "today.greeting.day": "Hi {name}",
    "today.greeting.evening": "Good evening, {name}",
    "today.window.active": "Your night window is on",
    "today.window.active.body": "Put your phone away. See you at 07:00.",
    "today.window.upcoming": "Tonight's window starts at {time}",
    "today.window.in": "in {h}h {m}m",
    "today.streak": "Your streak",
    "today.groupStreak": "Group streak",
    "today.nights": "{n} nights",
    "today.night1": "1 night",
    "today.lastNight": "Last night",
    "today.seeRecap": "See your night",
    "today.tip": "Wind-down tip",
    "today.challenge": "Challenge: night {n} of {total}",

    "recap.title": "Your night",
    "recap.phoneFree": "phone-free",
    "recap.window": "Your night, {start} – 07:00",
    "recap.free": "No phone use. Well done.",
    "recap.freeSmall": "Only a quick check ({min} min). Still a full moon.",
    "recap.used": "{min} min on your phone. The night broke at {time}.",
    "recap.toGroup": "See how the group did",

    "group.title": "{ok} of {n} phone-free",
    "group.lastNight": "Last night",
    "group.week": "Last 7 nights",
    "group.you": "you",
    "group.goal": "goal {time}",
    "group.react.hint": "Tap a moon to send 🌙, hold for more",
    "group.react.closed": "Reactions open again at 07:00",

    "history.title": "Your 14 nights",
    "history.free": "Phone-free nights",
    "history.best": "Longest streak",
    "history.legend": "What the moons mean",
    "history.future": "Still to come",

    "bucket.free": "Phone-free",
    "bucket.light": "2–5 min",
    "bucket.medium": "5–15 min",
    "bucket.heavy": "15–60 min",
    "bucket.very_heavy": "Over 60 min",
    "bucket.missing": "Not reported",

    "settings.title": "Settings",
    "settings.name": "Name",
    "settings.goal": "Phone down by",
    "settings.goal.note": "A new time applies from the next night.",
    "settings.language": "Language",
    "settings.demo": "Demo: allow reactions during the night",
    "settings.save": "Save",
    "settings.saved": "Saved",
    "settings.reset": "Start over",
    "settings.prototype": "Demo with made-up group data. Nothing is sent anywhere.",
    "settings.live": "Connected to group {group}.",
    "settings.name.locked": "Your name links you to your phone's measurements, so it can't be changed here.",

    "onb.demo": "Try the demo instead",
    "onb.err.network": "Couldn't connect. Check your internet and try again.",
    "loading": "Loading…",
    "error.load": "Couldn't load your group. Check your internet and pull to refresh.",
    "retry": "Try again",
    "empty.title": "Your first night is tonight",
    "empty.body": "Tomorrow morning you'll see how everyone did.",
    "react.failed": "Couldn't save your reaction",

    "tips": [
      "Charge your phone outside the bedroom tonight.",
      "Put a paper book on your pillow before dinner.",
      "Set your alarm, then put the phone face down out of reach.",
      "Dim the lights an hour before bed.",
      "Write down tomorrow's three tasks, then close the day.",
      "Tell someone in your group when you're putting your phone away.",
    ],
  },

  nl: {
    "tab.today": "Vandaag",
    "tab.group": "Groep",
    "tab.history": "Geschiedenis",
    "tab.settings": "Instellingen",

    "onb.welcome.title": "Slapen zonder je telefoon",
    "onb.welcome.body": "Moonlight checkt of je je telefoon tijdens je nacht hebt gebruikt, en laat elke ochtend zien hoe je groep het deed.",
    "onb.start": "Aan de slag",
    "onb.name": "Je naam",
    "onb.name.hint": "Zoals je groep hem moet zien",
    "onb.code": "Groepscode",
    "onb.code.hint": "Vraag het aan de organisator",
    "onb.goal": "Telefoon weg om",
    "onb.goal.hint": "Je nacht loopt van dit tijdstip tot 07:00.",
    "onb.platform": "Je telefoon",
    "onb.continue": "Verder",
    "onb.err.name": "Vul je naam in",
    "onb.err.code": "Deze code hoort niet bij een groep. Controleer hem bij de organisator.",
    "onb.setup.title": "Nog één stap",
    "onb.setup.ios": "Op een iPhone meet Moonlight met twee automatiseringen in de app Opdrachten. Je krijgt twee bestanden van de organisator; de handleiding kost ongeveer 5 minuten.",
    "onb.setup.android": "Op Android installeer je de Moonlight-meetapp, geef je toegang tot gebruiksgegevens en zet je batterijbesparing voor de app uit.",
    "onb.setup.home": "Zet deze pagina daarna op je beginscherm, dan opent hij als een app.",
    "onb.done": "Klaar",

    "today.greeting.morning": "Goedemorgen, {name}",
    "today.greeting.day": "Hoi {name}",
    "today.greeting.evening": "Goedenavond, {name}",
    "today.window.active": "Je nacht is begonnen",
    "today.window.active.body": "Leg je telefoon weg. Tot 07:00.",
    "today.window.upcoming": "Je nacht begint vanavond om {time}",
    "today.window.in": "over {h}u {m}m",
    "today.streak": "Jouw reeks",
    "today.groupStreak": "Groepsreeks",
    "today.nights": "{n} nachten",
    "today.night1": "1 nacht",
    "today.lastNight": "Afgelopen nacht",
    "today.seeRecap": "Bekijk je nacht",
    "today.tip": "Tip om tot rust te komen",
    "today.challenge": "Challenge: nacht {n} van {total}",

    "recap.title": "Jouw nacht",
    "recap.phoneFree": "telefoonvrij",
    "recap.window": "Jouw nacht, {start} – 07:00",
    "recap.free": "Geen telefoongebruik. Goed gedaan.",
    "recap.freeSmall": "Alleen even gekeken ({min} min). Nog steeds volle maan.",
    "recap.used": "{min} min op je telefoon. Om {time} was de nacht gebroken.",
    "recap.toGroup": "Bekijk hoe de groep het deed",

    "group.title": "{ok} van de {n} telefoonvrij",
    "group.lastNight": "Afgelopen nacht",
    "group.week": "Laatste 7 nachten",
    "group.you": "jij",
    "group.goal": "doel {time}",
    "group.react.hint": "Tik op een maan voor 🌙, houd vast voor meer",
    "group.react.closed": "Reageren kan weer vanaf 07:00",

    "history.title": "Jouw 14 nachten",
    "history.free": "Telefoonvrije nachten",
    "history.best": "Langste reeks",
    "history.legend": "Wat de manen betekenen",
    "history.future": "Komt nog",

    "bucket.free": "Telefoonvrij",
    "bucket.light": "2–5 min",
    "bucket.medium": "5–15 min",
    "bucket.heavy": "15–60 min",
    "bucket.very_heavy": "Meer dan 60 min",
    "bucket.missing": "Niet doorgegeven",

    "settings.title": "Instellingen",
    "settings.name": "Naam",
    "settings.goal": "Telefoon weg om",
    "settings.goal.note": "Een nieuwe tijd geldt vanaf de volgende nacht.",
    "settings.language": "Taal",
    "settings.demo": "Demo: reageren ook 's nachts toestaan",
    "settings.save": "Opslaan",
    "settings.saved": "Opgeslagen",
    "settings.reset": "Opnieuw beginnen",
    "settings.prototype": "Demo met verzonnen groepsgegevens. Er wordt niets verstuurd.",
    "settings.live": "Verbonden met groep {group}.",
    "settings.name.locked": "Je naam koppelt je aan de metingen van je telefoon, dus die kun je hier niet wijzigen.",

    "onb.demo": "Probeer liever de demo",
    "onb.err.network": "Geen verbinding. Controleer je internet en probeer het opnieuw.",
    "loading": "Laden…",
    "error.load": "Je groep kon niet worden geladen. Controleer je internet en probeer het opnieuw.",
    "retry": "Opnieuw proberen",
    "empty.title": "Je eerste nacht is vannacht",
    "empty.body": "Morgenochtend zie je hoe iedereen het deed.",
    "react.failed": "Je reactie kon niet worden opgeslagen",

    "tips": [
      "Laad je telefoon vannacht buiten de slaapkamer op.",
      "Leg voor het avondeten een papieren boek op je kussen.",
      "Zet je wekker en leg je telefoon daarna omgekeerd buiten bereik.",
      "Dim de lichten een uur voor het slapengaan.",
      "Schrijf de drie taken voor morgen op en sluit de dag af.",
      "Laat iemand uit je groep weten wanneer je je telefoon weglegt.",
    ],
  },
};

let lang = "en";

export function setLang(l) {
  lang = STRINGS[l] ? l : "en";
  document.documentElement.lang = lang;
}

export function getLang() {
  return lang;
}

export function t(key, vars = {}) {
  const v = STRINGS[lang][key] ?? STRINGS.en[key] ?? key;
  if (typeof v !== "string") return v;
  return v.replace(/\{(\w+)\}/g, (_, k) => (vars[k] ?? `{${k}}`));
}

export function guessLang() {
  return (navigator.language || "en").toLowerCase().startsWith("nl") ? "nl" : "en";
}
