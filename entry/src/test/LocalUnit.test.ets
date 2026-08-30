import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import databaseManagerTest from './ets/data/DatabaseManagerTest';
import fileInfoTest from './ets/data/FileInfoTest';
import fileRepositoryTest from './ets/data/FileRepositoryTest';
import collectionRepositoryTest from './ets/data/CollectionRepositoryTest';
import fileCollectionRefRepositoryTest from './ets/data/FileCollectionRefRepositoryTest';
import vectorStorageTierRepositoryTest from './ets/data/VectorStorageTierRepositoryTest';
import ragAnalysisLogRepositoryTest from './ets/data/RagAnalysisLogRepositoryTest';
import fileProcessingQueueTest from './ets/service/FileProcessingQueueTest';
import ragAnalysisServiceTest from './ets/service/RagAnalysisServiceTest';
import promptTemplatesTest from './ets/llm/PromptTemplatesTest';
import llmConfigTest from './ets/llm/LLMConfigTest';
import llmServiceTest from './ets/llm/LLMServiceTest';

export default function localUnitTest() {
  databaseManagerTest();
  fileInfoTest();
  fileRepositoryTest();
  collectionRepositoryTest();
  fileCollectionRefRepositoryTest();
  vectorStorageTierRepositoryTest();
  ragAnalysisLogRepositoryTest();
  fileProcessingQueueTest();
  ragAnalysisServiceTest();

  // LLM Tests
  promptTemplatesTest();
  llmConfigTest();
  llmServiceTest();

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
  });
}