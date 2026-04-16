// Trellegant – Default project template
// All dates are expressed as day offsets from the project start date.
// Modify this file to change what gets created when a user clicks "New Project".

'use strict';

const PROJECT_TEMPLATE = {
  // Trello lists (project phases)
  lists: [
    {
      name: 'Phase 1 — Planning & Discovery',
      cards: [
        {
          name: 'Project Kickoff',
          isMilestone: true,
          startOffset: 0,
          dueOffset: 0,
        },
        {
          name: 'Define scope & requirements',
          isMilestone: false,
          startOffset: 1,
          dueOffset: 5,
        },
        {
          name: 'Stakeholder alignment',
          isMilestone: false,
          startOffset: 3,
          dueOffset: 7,
        },
        {
          name: 'Create project schedule',
          isMilestone: false,
          startOffset: 5,
          dueOffset: 10,
        },
      ],
    },
    {
      name: 'Phase 2 — Execution & Delivery',
      cards: [
        {
          name: 'Design & architecture',
          isMilestone: false,
          startOffset: 10,
          dueOffset: 20,
        },
        {
          name: 'Build & implement',
          isMilestone: false,
          startOffset: 18,
          dueOffset: 35,
        },
        {
          name: 'Testing & review',
          isMilestone: false,
          startOffset: 33,
          dueOffset: 40,
        },
        {
          name: 'Project Delivery',
          isMilestone: true,
          startOffset: 42,
          dueOffset: 42,
        },
      ],
    },
    {
      name: 'Done',
      cards: [],
    },
  ],
};
