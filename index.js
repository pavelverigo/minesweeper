const canvas = document.getElementById("game");

const gl = canvas.getContext("webgl2");

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

const vertices = new Float32Array([
    100, 100,    1, 0, 0,
    100, 700,    0, 1, 0,
    700, 700,    0, 0, 1,
]);

gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);

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

// gl.drawArrays(gl.TRIANGLES, 0, vertices.length);

for (let ii = 0; ii < 128; ++ii) {
    const x = randomInt(800);
    const y = randomInt(800);
    const width = randomInt(400);
    const height = randomInt(400);
    const x1 = x - width / 2;
    const x2 = x + width / 2;
    const y1 = y - height / 2;
    const y2 = y + height / 2;
    const r = Math.random();
    const g = Math.random();
    const b = Math.random();
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
        x1, y1, r, g, b,
        x2, y1, r, g, b,
        x1, y2, r, g, b,
        x1, y2, r, g, b,
        x2, y1, r, g, b,
        x2, y2, r, g, b,
    ]), gl.DYNAMIC_READ);

    gl.drawArrays(gl.TRIANGLES, 0, 20);
}

function randomInt(range) {
  return Math.floor(Math.random() * range);
}