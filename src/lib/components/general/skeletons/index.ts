// Base skeleton loader component
export { default as SkeletonLoader } from './SkeletonLoader.svelte';

// Championship-specific skeletons (moved to campionat-continu)
export { default as RankingTableSkeleton } from '../../campionat-continu/RankingTableSkeleton.svelte';
export { default as ChallengeCardSkeleton } from '../../campionat-continu/ChallengeCardSkeleton.svelte';
export { default as WaitingListSkeleton } from '../../campionat-continu/WaitingListSkeleton.svelte';

// Form skeletons (moved to campionat-continu)
export { default as CreateChallengeSkeleton } from '../../campionat-continu/CreateChallengeSkeleton.svelte';
export { default as ChallengeResponseSkeleton } from '../../campionat-continu/ChallengeResponseSkeleton.svelte';
export { default as MatchResultSkeleton } from '../../campionat-continu/MatchResultSkeleton.svelte';

// Admin skeletons (moved to admin)
export { default as AdminDashboardSkeleton } from '../../admin/AdminDashboardSkeleton.svelte';