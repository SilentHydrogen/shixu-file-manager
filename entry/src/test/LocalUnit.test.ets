import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { wantConstant } from '@kit.AbilityKit';
import { buildFileOpenWant, buildFileSendWant, openTypeFromExtension } from '../main/ets/common/FileOpenWant';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });
    it('buildsOpenFileWantWithReadUriPermission', 0, () => {
      const uri: string = 'file://docs/storage/Users/current/report.pdf';
      const want = buildFileOpenWant(uri, 'pdf');
      expect(want.action).assertEqual('ohos.want.action.viewData');
      expect(want.uri).assertEqual(uri);
      expect(want.type).assertEqual('application/pdf');
      expect(want.flags).assertEqual(wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION);
      expect(want.parameters !== undefined).assertTrue();
      expect((want.parameters as Record<string, Object>)['ohos.ability.params.showDefaultPicker']).assertEqual(true);
    });
    it('usesOpenXmlMimeForDocx', 0, () => {
      expect(openTypeFromExtension('doc')).assertEqual('application/msword');
      expect(openTypeFromExtension('docx')).assertEqual('application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    });
    it('buildsSendWantWithStreamForOfficeApps', 0, () => {
      const uri: string = 'file://com.cdyangzheng.filebox/data/storage/el2/base/files/open_proxy/report.docx';
      const want = buildFileSendWant(uri, 'docx');
      expect(want.action).assertEqual('ohos.want.action.sendData');
      expect(want.uri).assertEqual(uri);
      expect(want.type).assertEqual('application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      expect(want.flags).assertEqual(wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION);
      expect(want.parameters !== undefined).assertTrue();
      const streams: string[] = (want.parameters as Record<string, Object>)['ability.params.stream'] as string[];
      expect(streams.length).assertEqual(1);
      expect(streams[0]).assertEqual(uri);
    });
    it('doesNotUseWildcardForUnknownOpenType', 0, () => {
      const uri: string = 'file://docs/storage/Users/current/archive.unknown';
      const want = buildFileOpenWant(uri, 'unknown');
      expect(openTypeFromExtension('unknown')).assertEqual('');
      expect(want.type === undefined).assertTrue();
      expect(want.flags).assertEqual(wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION);
      expect(want.parameters !== undefined).assertTrue();
      expect((want.parameters as Record<string, Object>)['ohos.ability.params.showDefaultPicker']).assertEqual(true);
    });
  });
}
