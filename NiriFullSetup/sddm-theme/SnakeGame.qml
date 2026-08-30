import QtQuick

Item {
    id: root
    width: 400
    height: 460

    property int gridN: 16
    property int score: 0
    property bool gameOver: false

    property var segs: []
    property var dir: ({ x: 1, y: 0 })
    property var nextDir: ({ x: 1, y: 0 })
    property var food: ({ x: 0, y: 0 })

    function restart() {
        segs = [ { x: 8, y: 8 }, { x: 7, y: 8 }, { x: 6, y: 8 } ]
        dir = { x: 1, y: 0 }
        nextDir = { x: 1, y: 0 }
        food = randFood()
        score = 0
        gameOver = false
        loop.start()
        canvas.requestPaint()
    }

    function randFood() {
        var p
        var tries = 0
        do {
            p = { x: Math.floor(Math.random() * gridN), y: Math.floor(Math.random() * gridN) }
            tries++
        } while (tries < 200 && segs.some(function (s) { return s.x === p.x && s.y === p.y }))
        return p
    }

    function handleDirection(key) {
        var nd = null
        if (key === Qt.Key_Up) nd = { x: 0, y: -1 }
        else if (key === Qt.Key_Down) nd = { x: 0, y: 1 }
        else if (key === Qt.Key_Left) nd = { x: -1, y: 0 }
        else if (key === Qt.Key_Right) nd = { x: 1, y: 0 }
        if (!nd) return
        if (nd.x === -dir.x && nd.y === -dir.y) return
        nextDir = nd
    }

    function tick() {
        dir = nextDir
        var head = { x: segs[0].x + dir.x, y: segs[0].y + dir.y }
        var hitWall = head.x < 0 || head.y < 0 || head.x >= gridN || head.y >= gridN
        var hitSelf = segs.some(function (s) { return s.x === head.x && s.y === head.y })
        if (hitWall || hitSelf) {
            loop.stop()
            gameOver = true
            return
        }
        var newSegs = segs.slice()
        newSegs.unshift(head)
        if (head.x === food.x && head.y === food.y) {
            score += 1
            food = randFood()
        } else {
            newSegs.pop()
        }
        segs = newSegs
        canvas.requestPaint()
    }

    Component.onCompleted: restart()
    Component.onDestruction: loop.stop()

    Timer { id: loop; interval: 140; repeat: true; onTriggered: root.tick() }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Row {
            width: 384
            Text { text: "Snake"; color: "#f2ede6"; font.pixelSize: 16; font.bold: true }
            Item { width: 384 - 90 - snakeScoreText.width; height: 1 }
            Text { id: snakeScoreText; text: "Score " + root.score; color: "#f2ede6a0"; font.pixelSize: 13 }
        }

        Rectangle {
            width: 384; height: 384; radius: 8; color: "#0d0d0d"
            border.color: "#ffffff1a"; border.width: 1
            clip: true

            Canvas {
                id: canvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    var cell = width / root.gridN
                    ctx.fillStyle = "#0d0d0d"
                    ctx.fillRect(0, 0, width, height)
                    ctx.fillStyle = "#e0674f"
                    ctx.fillRect(root.food.x * cell + 3, root.food.y * cell + 3, cell - 6, cell - 6)
                    for (var i = 0; i < root.segs.length; i++) {
                        ctx.globalAlpha = i === 0 ? 1 : 0.82
                        ctx.fillStyle = "#f2ede6"
                        ctx.fillRect(root.segs[i].x * cell + 1, root.segs[i].y * cell + 1, cell - 2, cell - 2)
                    }
                    ctx.globalAlpha = 1
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#0a0908d2"
                visible: root.gameOver
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Game Over"; color: "#f2ede6"; font.pixelSize: 18; font.bold: true }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Score " + root.score; color: "#f2ede6a0"; font.pixelSize: 13 }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: restartLabel.width + 32; height: 34; radius: 10
                        color: restartMa.containsMouse ? "#ffffff1a" : "#ffffff0a"
                        border.color: "#ffffff20"; border.width: 1
                        Text { id: restartLabel; anchors.centerIn: parent; text: "Restart"; color: "#f2ede6"; font.pixelSize: 13 }
                        MouseArea { id: restartMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.restart() }
                    }
                }
            }
        }

        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Arrow keys to move · Esc to exit"; color: "#f2ede660"; font.pixelSize: 11 }
    }
}
