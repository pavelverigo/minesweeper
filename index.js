const canvas = document.getElementById("game");

const gl = canvas.getContext("webgl2",{
    antialias: true,
    depth: false,
    preserveDrawingBuffer: true,
});

const vertexShaderSource = `#version 300 es

in vec2 a_position;
in vec3 a_color;
out vec3 v_color;
uniform vec2 u_resolution;

void main() {
    vec2 clipSpace = (a_position / u_resolution) * 2.0 - 1.0;
    // rotate for left-top corner
    gl_Position = vec4(clipSpace * vec2(1, -1), 0, 1);

    v_color = a_color;
}
`;
 
const fragmentShaderSource = `#version 300 es
precision highp float;
 
in vec3 v_color;
out vec4 outColor;

void main() {
  outColor = vec4(v_color, 1);
}
`;

function createShader(gl, type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    const success = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
    if (success) {
        return shader;
    }

    console.log(gl.getShaderInfoLog(shader));
    gl.deleteShader(shader);
}

const vertexShader = createShader(gl, gl.VERTEX_SHADER, vertexShaderSource);
const fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, fragmentShaderSource);

function createProgram(gl, vertexShader, fragmentShader) {
    const program = gl.createProgram();
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);
    const success = gl.getProgramParameter(program, gl.LINK_STATUS);
    if (success) {
        return program;
    }
   
    console.log(gl.getProgramInfoLog(program));
    gl.deleteProgram(program);
}

const program = createProgram(gl, vertexShader, fragmentShader);

const a_position = gl.getAttribLocation(program, 'a_position');
const a_color = gl.getAttribLocation(program, 'a_color');

const resolutionUniformLocation = gl.getUniformLocation(program, "u_resolution");

const vertexBuffer = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);

const vao = gl.createVertexArray();

gl.bindVertexArray(vao);

gl.vertexAttribPointer(a_position, 2, gl.FLOAT, false, 20, 0);
gl.enableVertexAttribArray(a_position);

gl.vertexAttribPointer(a_color, 3, gl.FLOAT, false, 20, 8);
gl.enableVertexAttribArray(a_color);

gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);

gl.clearColor(0, 0, 0, 1);
gl.clear(gl.COLOR_BUFFER_BIT);

gl.useProgram(program);
gl.uniform2f(resolutionUniformLocation, gl.canvas.width, gl.canvas.height);

let memory;
const imports = {
    env: {
        draw: (offset, vertexCount) => {
            gl.clear(gl.COLOR_BUFFER_BIT);

            const v = new Float32Array(memory.buffer, offset, vertexCount * 5);
            gl.bufferData(gl.ARRAY_BUFFER, v, gl.DYNAMIC_DRAW);
            gl.drawArrays(gl.TRIANGLES, 0, vertexCount);
        },
    },
};
const wasm = await WebAssembly.instantiateStreaming(fetch("zig-out/lib/minesweeper.wasm"), imports);
memory = wasm.instance.exports.memory;

const frame = wasm.instance.exports.frame;
const click = wasm.instance.exports.click;

const mouseState = {
    mouseX: 0,
    mouseY: 0,
    mouseInside: false,
};

function handleClick(e) {
    e.preventDefault();
    click(e.offsetX, e.offsetY, e.button);
}

canvas.addEventListener('click', handleClick);
canvas.addEventListener('auxclick', handleClick);
canvas.addEventListener('contextmenu', handleClick);

canvas.addEventListener('mousemove', (e) => {
    mouseState.mouseX = e.offsetX;
    mouseState.mouseY = e.offsetY;
    mouseState.mouseInside = true;
});

canvas.addEventListener('mouseout', () => {
    mouseState.mouseInside = false;
});

function browserFrame() {
    frame();

    requestAnimationFrame(browserFrame);
}

browserFrame();
