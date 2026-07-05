// Test: verify optimization that avoids re-converting historical function_calls
const proxy = require('../src/proxy');
const assert = require('assert');

const fakeStore = new Map();

function simulateTurn(instructions, inputItems, tools, previousResponseId) {
    const body = {
        instructions, input: inputItems, tools,
        model: 'deepseek-v4-pro', previous_response_id: previousResponseId,
    };
    const chatReq = proxy.buildChatRequest(body);
    return { body, chatReq };
}

function getLastAssistantToolCallIds(storedMsgs) {
    const ids = new Set();
    for (let i = storedMsgs.length - 1; i >= 0; i--) {
        const m = storedMsgs[i];
        if (m.role === 'assistant' && Array.isArray(m.tool_calls)) {
            m.tool_calls.forEach(tc => ids.add(tc.id));
            break;
        }
    }
    return ids;
}

function filterNewItems(input, storedMsgs, lastToolCallIds) {
    const newItems = [];
    let seenFirstOutput = false;
    for (const item of input) {
        if (!item || typeof item !== 'object') continue;
        if (item.type === 'function_call') continue;
        if (item.type === 'function_call_output') {
            if (lastToolCallIds.has(item.call_id)) { newItems.push(item); seenFirstOutput = true; }
            continue;
        }
        if (item.type === 'message' || item.role || item.type === 'input_text') {
            if (seenFirstOutput) newItems.push(item);
            continue;
        }
        newItems.push(item);
    }
    return newItems;
}

function buildOptimizedMessages(body, previous, newConvertedItems) {
    const messages = [];
    if (body.instructions) messages.push({ role: 'system', content: String(body.instructions) });
    const injected = process.env.DEEPSEEK_INJECT_SYSTEM_PROMPT;
    if (injected) messages.push({ role: 'system', content: injected });
    const hasSystem = messages.length > 0;
    const prevStart = hasSystem && previous[0]?.role === 'system' ? 1 : 0;
    for (let i = prevStart; i < previous.length; i++) messages.push(previous[i]);
    messages.push(...newConvertedItems);
    return messages;
}

// ========== TEST ==========
const tools = [{ type: 'shell_command', description: 'Run cmd', input_schema: { type: 'object', properties: { cmd: { type: 'string' } } } }];
const instructions = 'You are Codex.';

// TURN 1
console.log('=== TURN 1 ===');
const t1 = simulateTurn(instructions, [
    { type: 'message', role: 'user', content: [{ type: 'input_text', text: 'read file' }] }
], tools, null);
console.log('Messages:', t1.chatReq.messages.length);
t1.chatReq.messages.forEach((m, i) => console.log('  [%d] %s | %s', i, m.role, (m.content || '').slice(0, 50)));

const ds1 = { choices: [{ message: { content: '', tool_calls: [{ id: 'call_001', type: 'function', function: { name: 'shell_command', arguments: '{"cmd":"cat f.txt"}' } }] } }], usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 } };
const r1 = proxy.responseFromChat(t1.body, t1.chatReq, ds1);
const stored1 = [...t1.chatReq.messages];
stored1.push({ role: 'assistant', content: '', tool_calls: ds1.choices[0].message.tool_calls });
fakeStore.set(r1.id, stored1);

// TURN 2
console.log('\n=== TURN 2 ===');
const t2 = simulateTurn(instructions, [
    { type: 'message', role: 'user', content: [{ type: 'input_text', text: 'read file' }] },
    { type: 'function_call', call_id: 'call_001', name: 'shell_command', arguments: '{"cmd":"cat f.txt"}' },
    { type: 'function_call_output', call_id: 'call_001', output: 'hello world' },
    { type: 'message', role: 'user', content: [{ type: 'input_text', text: 'now check size' }] },
], tools, r1.id);

console.log('CURRENT messages:', t2.chatReq.messages.length);
t2.chatReq.messages.forEach((m, i) => console.log('  [%d] %s | %s %s', i, m.role, (m.content || '').slice(0, 50), m.tool_calls ? 'tc='+m.tool_calls.length : '', m.tool_call_id ? 'cid='+m.tool_call_id : ''));

const previous2 = fakeStore.get(r1.id);
const lastCallIds2 = getLastAssistantToolCallIds(previous2);
const newItems2 = filterNewItems(t2.body.input, previous2, lastCallIds2);
const newConverted2 = proxy.convertInputItems(newItems2);
const optimized2 = buildOptimizedMessages(t2.body, previous2, newConverted2);

console.log('\nOPTIMIZED messages:', optimized2.length);
optimized2.forEach((m, i) => console.log('  [%d] %s | %s %s', i, m.role, (m.content || '').slice(0, 50), m.tool_calls ? 'tc='+m.tool_calls.length : '', m.tool_call_id ? 'cid='+m.tool_call_id : ''));

assert.strictEqual(t2.chatReq.messages.length, optimized2.length);
for (let i = 0; i < t2.chatReq.messages.length; i++) {
    const c = t2.chatReq.messages[i], o = optimized2[i];
    assert.strictEqual(c.role, o.role, 'Role@' + i);
    if (c.role === 'assistant' && c.tool_calls && o.tool_calls) {
        assert.strictEqual(c.tool_calls.length, o.tool_calls.length);
        for (let j = 0; j < c.tool_calls.length; j++) {
            assert.strictEqual(c.tool_calls[j].id, o.tool_calls[j].id);
            assert.strictEqual(c.tool_calls[j].function.name, o.tool_calls[j].function.name);
        }
    }
    if (c.role === 'tool') { assert.strictEqual(c.tool_call_id, o.tool_call_id); assert.strictEqual(c.content, o.content); }
}
console.log('T2 VERIFIED');

// TURN 3
console.log('\n=== TURN 3 ===');
const ds2 = { choices: [{ message: { content: 'The file contains hello world.', tool_calls: [{ id: 'call_002', type: 'function', function: { name: 'shell_command', arguments: '{"cmd":"wc -c f.txt"}' } }] } }], usage: { prompt_tokens: 20, completion_tokens: 10, total_tokens: 30 } };
const stored2 = [...t2.chatReq.messages];
stored2.push({ role: 'assistant', content: 'The file contains hello world.', tool_calls: ds2.choices[0].message.tool_calls });
fakeStore.set('resp_t2', stored2);

const t3 = simulateTurn(instructions, [
    { type: 'message', role: 'user', content: [{ type: 'input_text', text: 'read file' }] },
    { type: 'function_call', call_id: 'call_001', name: 'shell_command', arguments: '{"cmd":"cat f.txt"}' },
    { type: 'function_call_output', call_id: 'call_001', output: 'hello world' },
    { type: 'function_call', call_id: 'call_002', name: 'shell_command', arguments: '{"cmd":"wc -c f.txt"}' },
    { type: 'function_call_output', call_id: 'call_002', output: '28 f.txt' },
    { type: 'message', role: 'user', content: [{ type: 'input_text', text: 'thanks' }] },
], tools, 'resp_t2');

console.log('CURRENT messages:', t3.chatReq.messages.length);
t3.chatReq.messages.forEach((m, i) => console.log('  [%d] %s | %s %s', i, m.role, (m.content || '').slice(0, 50), m.tool_calls ? 'tc='+m.tool_calls.length : '', m.tool_call_id ? 'cid='+m.tool_call_id : ''));

const previous3 = fakeStore.get('resp_t2');
const lastCallIds3 = getLastAssistantToolCallIds(previous3);
const newItems3 = filterNewItems(t3.body.input, previous3, lastCallIds3);
const newConverted3 = proxy.convertInputItems(newItems3);
const optimized3 = buildOptimizedMessages(t3.body, previous3, newConverted3);

console.log('\nOPTIMIZED messages:', optimized3.length);
optimized3.forEach((m, i) => console.log('  [%d] %s | %s %s', i, m.role, (m.content || '').slice(0, 50), m.tool_calls ? 'tc='+m.tool_calls.length : '', m.tool_call_id ? 'cid='+m.tool_call_id : ''));

assert.strictEqual(t3.chatReq.messages.length, optimized3.length);
for (let i = 0; i < t3.chatReq.messages.length; i++) {
    const c = t3.chatReq.messages[i], o = optimized3[i];
    assert.strictEqual(c.role, o.role, 'Role@' + i);
    if (c.role === 'assistant' && c.tool_calls && o.tool_calls) {
        assert.strictEqual(c.tool_calls.length, o.tool_calls.length);
        for (let j = 0; j < c.tool_calls.length; j++) {
            assert.strictEqual(c.tool_calls[j].id, o.tool_calls[j].id);
            assert.strictEqual(c.tool_calls[j].function.name, o.tool_calls[j].function.name);
        }
    }
    if (c.role === 'tool') { assert.strictEqual(c.tool_call_id, o.tool_call_id); assert.strictEqual(c.content, o.content); }
}
console.log('T3 VERIFIED');

// Summary
console.log('\n=== TOKEN SAVINGS ===');
console.log('Turn 2: input items %d -> new items %d (skipped %d)', t2.body.input.length, newItems2.length, t2.body.input.length - newItems2.length);
console.log('Turn 3: input items %d -> new items %d (skipped %d)', t3.body.input.length, newItems3.length, t3.body.input.length - newItems3.length);
console.log('In long convos with N historical calls: skip ~2N items/turn');
console.log('\nALL TESTS PASSED');
