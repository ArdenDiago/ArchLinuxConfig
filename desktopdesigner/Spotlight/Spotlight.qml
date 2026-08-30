import QtQuick
import Quickshell
import Quickshell.Io
import qs.Theme

// docs/03-spotlight.md MVP: Application provider (fuzzy match) + '=' web
// search/URL + '/' calculator. Provider split into separate Providers/*.qml
// files is real structure for a bigger build; collapsed into one file here
// since each provider is currently ~20 lines — split out if any one grows.
// '>' '?' ':' '@' '#' prefixes are explicitly future-scoped in the doc.
PanelWindow {
    id: root
    property bool active: false
    visible: active
    focusable: active

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    onActiveChanged: {
        if (active) {
            query = "";
            selectedIndex = 0;
            appScan.running = true;
            Qt.callLater(() => searchField.forceActiveFocus());
        }
    }

    function open() {
        active = true;
    }

    function close() {
        active = false;
    }

    function toggle() {
        active = !active;
    }

    property string query: ""
    property var apps: []
    property var results: []
    property int selectedIndex: 0
    // "applications" | "web" | "calculator"
    property string mode: "applications"

    onQueryChanged: _route()

    function _route() {
        if (query.startsWith("=")) {
            mode = "web";
            results = [];
        } else if (query.startsWith("/")) {
            mode = "calculator";
            results = [_evalCalculator(query.slice(1))];
        } else {
            mode = "applications";
            results = _fuzzyFilter(query, apps);
        }
        selectedIndex = 0;
    }

    function _fuzzyFilter(q, list) {
        if (!q)
            return list.slice(0, 9);
        const needle = q.toLowerCase();
        const scored = [];
        for (const app of list) {
            const hay = app.name.toLowerCase();
            let score = -1;
            if (hay.startsWith(needle))
                score = 100 - hay.length;
            else if (hay.includes(needle))
                score = 50 - hay.length;
            else {
                // subsequence match
                let hi = 0;
                let matched = 0;
                for (let ni = 0; ni < needle.length; ni++) {
                    const idx = hay.indexOf(needle[ni], hi);
                    if (idx === -1)
                        break;
                    hi = idx + 1;
                    matched++;
                }
                if (matched === needle.length)
                    score = 10 - hay.length * 0.1;
            }
            if (score > -1)
                scored.push({
                    "app": app,
                    "score": score
                });
        }
        scored.sort((a, b) => b.score - a.score);
        return scored.slice(0, 9).map(s => s.app);
    }

    function _evalCalculator(expr) {
        if (!expr.trim())
            return {
                "name": "",
                "isCalc": true
            };
        try {
            let js = expr.replace(/\bpi\b/gi, "Math.PI").replace(/\be\b/g, "Math.E").replace(/\b(sin|cos|tan|asin|acos|atan|log|sqrt|abs|floor|ceil|round|min|max|pow)\s*\(/g, "Math.$1(").replace(/\^/g, "**");
            if (!/^[\d\s+\-*/%().,Math\w]*$/.test(js))
                throw "invalid";
            const value = Function('"use strict"; return (' + js + ")")();
            if (typeof value !== "number" || !isFinite(value))
                throw "invalid";
            return {
                "name": String(Math.round(value * 1e10) / 1e10),
                "isCalc": true,
                "value": value
            };
        } catch (e) {
            return {
                "name": "…",
                "isCalc": true
            };
        }
    }

    function _isUrl(s) {
        return /^[a-z]+:\/\//i.test(s) || /^[\w-]+(\.[\w-]+)+(\/.*)?$/.test(s);
    }

    function launch(app) {
        if (!app)
            return;
        if (mode === "web") {
            const q = query.slice(1).trim();
            let url = q;
            if (_isUrl(q)) {
                if (!/^[a-z]+:\/\//i.test(url))
                    url = "https://" + url;
            } else {
                url = "https://www.google.com/search?q=" + encodeURIComponent(q);
            }
            Quickshell.execDetached(["xdg-open", url]);
            close();
            return;
        }
        if (mode === "calculator") {
            if (app.value !== undefined)
                Quickshell.execDetached(["sh", "-c", `printf '%s' '${String(app.value)}' | wl-copy`]);
            close();
            return;
        }
        if (app.exec) {
            Quickshell.execDetached(["sh", "-c", app.exec]);
        }
        close();
    }

    Process {
        id: appScan
        command: ["sh", "-c", "for f in /usr/share/applications/*.desktop $HOME/.local/share/applications/*.desktop; do [ -f \"$f\" ] || continue; grep -q '^NoDisplay=true' \"$f\" && continue; name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/%[a-zA-Z]//g'); [ -z \"$name\" ] && continue; printf '%s\\t%s\\n' \"$name\" \"$exec\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Set();
                const list = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const [name, exec] = line.split("\t");
                    if (!name || seen.has(name))
                        continue;
                    seen.add(name);
                    list.push({
                        "name": name,
                        "exec": exec || ""
                    });
                }
                root.apps = list;
                root._route();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.45

        TapHandler {
            onTapped: root.close()
        }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.18
        width: 620
        height: Math.min(parent.height * 0.7, headerRow.height + resultsColumn.height + 32)
        radius: Theme.radius.large
        color: Theme.color.surface
        border.width: 0

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Row {
                id: headerRow
                width: parent.width
                spacing: 8

                Text {
                    text: root.mode === "web" ? "🌐" : root.mode === "calculator" ? "🧮" : "🔍"
                    font.pixelSize: Theme.font.large
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: searchField
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.large
                    color: Theme.color.surfaceText
                    clip: true
                    text: root.query
                    onTextChanged: root.query = text

                    Keys.onDownPressed: root.selectedIndex = Math.min(root.results.length - 1, root.selectedIndex + 1)
                    Keys.onUpPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: root.launch(root.results[root.selectedIndex])

                    Text {
                        visible: !searchField.text
                        text: "Search applications, = to search web, / to calculate…"
                        color: Theme.color.surfaceVariantText
                        font.family: Theme.font.family
                        font.pixelSize: Theme.font.large
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.color.outline
                visible: resultsColumn.height > 0
            }

            Column {
                id: resultsColumn
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.results
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: resultsColumn.width
                        height: 40
                        radius: Theme.radius.small
                        color: index === root.selectedIndex ? Theme.color.accentContainer : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: index === root.selectedIndex ? Theme.color.accentText : Theme.color.surfaceText
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.normal
                        }

                        TapHandler {
                            onTapped: root.launch(modelData)
                        }
                    }
                }

                Text {
                    visible: root.query.length > 0 && root.results.length === 0 && root.mode === "applications"
                    width: resultsColumn.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "No Results Found"
                    color: Theme.color.surfaceVariantText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.normal
                    topPadding: 12
                    bottomPadding: 12
                }
            }
        }
    }
}
