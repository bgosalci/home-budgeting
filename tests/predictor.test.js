import { predict, learn } from '../app/js/modules/predictor.js';
import { setMapping } from '../app/js/modules/store.js';

beforeEach(()=>{
  setMapping({exact:{}, tokens:{}});
});

test('learn and predict exact by description', ()=>{
  learn('Tesco', 'Food');
  expect(predict('Tesco', ['Food','Rent'])).toBe('Food');
});

test('learn and predict with amount key', ()=>{
  learn('Uber', 'Transport', 12.50);
  expect(predict('Uber', ['Transport'], 12.5)).toBe('Transport');
  expect(predict('Uber', ['Transport'], 15)).toBe('Transport');
});

test('token-based prediction prefers learned category', ()=>{
  learn('Gym monthly', 'Leisure');
  learn('Gym day pass', 'Leisure');
  const cat = predict('Gym', ['Leisure','Food']);
  expect(cat).toBe('Leisure');
});
