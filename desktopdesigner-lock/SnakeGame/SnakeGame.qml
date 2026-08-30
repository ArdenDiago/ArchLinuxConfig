import QtQuick
import qs.Theme

// docs/01-lockscreen.md's hidden Ctrl+G distraction — a real, playable
// Snake (grid movement, food, self/wall collision, score), not a stub.
// Explicitly has zero imports of Services/Pam or any session/auth type —
// per the doc's security note, it must not be able to reach anything
// session-related even by accident.
Item {
    id: root
    property bool active: false
    visible: active
    focus: active

    readonly property int cols: 24
    readonly property int rows: 16
    readonly property int cellSize: 20

    property var snake: [[12, 8], [11, 8], [10, 8]]
    property var direction: [1, 0]
    property var pendingDirection: [1, 0]
    property var food: [18, 8]
    property int score: 0
    property int highScore: 0
    property bool gameOver: false
    property bool paused: false

    signal exitRequested

    function reset() {
        snake = [[12, 8], [11, 8], [10, 8]];
        direction = [1, 0];
        pendingDirection = [1, 0];
        score = 0;
        gameOver = false;
        paused = false;
        placeFood();
    }

    function placeFood() {
        let candidate;
        do {
            candidate = [Math.floor(Math.random() * cols), Math.floor(Math.random() * rows)];
        } while (snake.some(s => s[0] === candidate[0] && s[1] === candidate[1]));
        food = candidate;
    }

    function tick() {
        if (gameOver || paused || !active)
            return;
        direction = pendingDirection;
        const head = snake[0];
        const next = [head[0] + direction[0], head[1] + direction[1]];

        if (next[0] < 0 || next[0] >= cols || next[1] < 0 || next[1] >= rows || snake.some(s => s[0] === next[0] && s[1] === next[1])) {
            gameOver = true;
            highScore = Math.max(highScore, score);
            return;
        }

        const grew = next[0] === food[0] && next[1] === food[1];
        const newSnake = [next, ...snake.slice(0, grew ? snake.length : snake.length - 1)];
        snake = newSnake;
        if (grew) {
            score += 10;
            placeFood();
        }
    }

    onActiveChanged: if (active)
        reset()

    Timer {
        interval: 130
        running: root.active
        repeat: true
        onTriggered: root.tick()
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.cols * root.cellSize + 32
        height: root.rows * root.cellSize + 80
        radius: Theme.radius.large
        color: Theme.color.surface
        opacity: 0.95
        border.width: 1
        border.color: Theme.color.outline

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            Row {
                width: parent.width
                Text {
                    text: "Score " + root.score
                    color: Theme.color.surfaceText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.normal
                }
                Item {
                    width: parent.width - 220
                    height: 1
                }
                Text {
                    text: "High " + root.highScore
                    color: Theme.color.surfaceVariantText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.normal
                }
            }

            Rectangle {
                width: root.cols * root.cellSize
                height: root.rows * root.cellSize
                radius: Theme.radius.medium
                color: Theme.color.surfaceContainer
                clip: true

                Repeater {
                    model: root.snake
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        x: modelData[0] * root.cellSize
                        y: modelData[1] * root.cellSize
                        width: root.cellSize - 2
                        height: root.cellSize - 2
                        radius: 4
                        color: index === 0 ? Theme.color.accent : Theme.color.accentContainer
                    }
                }

                Rectangle {
                    x: root.food[0] * root.cellSize
                    y: root.food[1] * root.cellSize
                    width: root.cellSize - 2
                    height: root.cellSize - 2
                    radius: root.cellSize
                    color: Theme.color.error
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.gameOver
                    text: "Game Over — R to restart"
                    color: Theme.color.surfaceText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.normal
                }
            }

            Text {
                text: "Arrows/WASD move · P pause · R restart · Esc exit"
                color: Theme.color.surfaceVariantText
                font.family: Theme.font.family
                font.pixelSize: Theme.font.small
            }
        }
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_W:
            if (direction[1] === 0)
                pendingDirection = [0, -1];
            break;
        case Qt.Key_Down:
        case Qt.Key_S:
            if (direction[1] === 0)
                pendingDirection = [0, 1];
            break;
        case Qt.Key_Left:
        case Qt.Key_A:
            if (direction[0] === 0)
                pendingDirection = [-1, 0];
            break;
        case Qt.Key_Right:
        case Qt.Key_D:
            if (direction[0] === 0)
                pendingDirection = [1, 0];
            break;
        case Qt.Key_P:
            paused = !paused;
            break;
        case Qt.Key_R:
            reset();
            break;
        case Qt.Key_Escape:
            root.exitRequested();
            break;
        }
        event.accepted = true;
    }
}
