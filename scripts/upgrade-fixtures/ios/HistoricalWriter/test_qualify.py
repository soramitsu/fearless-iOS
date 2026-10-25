import copy
import unittest
from qualify import require_summary, require_tests, REQUIRED_TESTS

class QualificationGateTests(unittest.TestCase):
    def valid(self):
        return dict(passedTests=6, failedTests=0, skippedTests=0, expectedFailures=0, totalTestCount=6)

    def test_exact_real_six_passes_are_accepted(self):
        require_summary(self.valid())

    def test_missing_empty_skipped_failed_and_unexpected_counts_are_rejected(self):
        invalid = [{}, dict(passedTests=0), {**self.valid(), 'passedTests': 0, 'totalTestCount': 0}]
        for key in self.valid():
            missing = self.valid(); del missing[key]; invalid.append(missing)
            changed = self.valid(); changed[key] += 1; invalid.append(changed)
            invalid.append({**self.valid(), key: str(self.valid()[key])})
        invalid.append({**self.valid(), 'passedTests': 5, 'skippedTests': 1})
        for summary in invalid:
            with self.subTest(summary=summary), self.assertRaises(ValueError):
                require_summary(summary)

    def test_named_results_and_runtime_are_required(self):
        nodes=[dict(nodeType='Test Case', nodeIdentifier='KeychainContinuityTests/'+name+'()', result='Passed') for name in sorted(REQUIRED_TESTS)]
        valid=dict(testNodes=[dict(children=nodes)], devices=[dict(deviceId='owned', osVersion='26.5', platform='iOS Simulator')])
        self.assertEqual(len(require_tests(valid, 'owned')), 6)
        mutations=[]
        wrong=copy.deepcopy(valid);wrong['testNodes'][0]['children'][0]['nodeIdentifier']='Other/test()';mutations.append(wrong)
        wrong=copy.deepcopy(valid);wrong['testNodes'][0]['children'][0]['result']='Skipped';mutations.append(wrong)
        wrong=copy.deepcopy(valid);wrong['testNodes'][0]['children'].append(nodes[0]);mutations.append(wrong)
        wrong=copy.deepcopy(valid);wrong['devices'][0]['osVersion']='18.1';mutations.append(wrong)
        wrong=copy.deepcopy(valid);wrong['devices'][0]['deviceId']='other';mutations.append(wrong)
        wrong=copy.deepcopy(valid);wrong['devices']=[];mutations.append(wrong)
        for tree in [{}, *mutations]:
            with self.subTest(tree=tree), self.assertRaises(ValueError): require_tests(tree, 'owned')

if __name__ == '__main__': unittest.main()
