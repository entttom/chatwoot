import { shallowMount } from '@vue/test-utils';
import messageFormatterMixin from '../messageFormatterMixin';

describe('messageFormatterMixin', () => {
  it('returns correct plain text', () => {
    const Component = {
      render() {},
      mixins: [messageFormatterMixin],
    };
    const wrapper = shallowMount(Component);
    const message =
      '<b>Chattlin is an opensource tool. https://www.chattlin.com</b>';
    expect(wrapper.vm.getPlainText(message)).toMatch(
      'Chattlin is an opensource tool. https://www.chattlin.com'
    );
  });

  it('stripStyleCharacters returns message without style tags', () => {
    const Component = {
      render() {},
      mixins: [messageFormatterMixin],
    };
    const wrapper = shallowMount(Component);
    const message =
      '<b style="max-width:100%">Chattlin is an opensource tool. https://www.chattlin.com</b><style type="css">.message{}</style>';
    expect(wrapper.vm.stripStyleCharacters(message)).toMatch(
      '<b>Chattlin is an opensource tool. https://www.chattlin.com</b>'
    );
  });
});
