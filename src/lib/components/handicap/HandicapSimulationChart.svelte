<script lang="ts">
	import { onMount } from 'svelte';
	import * as echarts from 'echarts';

	export let dates: string[] = [];
	export let dataFi: string = '';
	export let p10: string | null = null;
	export let p50: string | null = null;
	export let p90: string | null = null;

	let chartDom: HTMLDivElement;
	let chart: echarts.ECharts | null = null;

	function bucketize(ds: string[]): { x: string[]; y: number[] } {
		if (ds.length === 0) return { x: [], y: [] };
		const sorted = [...ds].sort();
		const min = sorted[0];
		const max = sorted[sorted.length - 1];
		const buckets = new Map<string, number>();

		// Bucket = 1 dia exacte
		const cur = parseLocal(min);
		const end = parseLocal(max);
		while (cur <= end) {
			buckets.set(fmt(cur), 0);
			cur.setDate(cur.getDate() + 1);
		}

		for (const d of ds) buckets.set(d, (buckets.get(d) ?? 0) + 1);

		const x = [...buckets.keys()].sort();
		const y = x.map((k) => buckets.get(k)!);
		return { x, y };
	}

	function parseLocal(s: string): Date {
		const [y, m, d] = s.split('-').map(Number);
		return new Date(y, m - 1, d);
	}

	function fmt(d: Date): string {
		const y = d.getFullYear();
		const m = String(d.getMonth() + 1).padStart(2, '0');
		const dd = String(d.getDate()).padStart(2, '0');
		return `${y}-${m}-${dd}`;
	}

	function buildOption(): echarts.EChartsOption {
		const { x, y } = bucketize(dates);
		const markLines: any[] = [];
		if (p10) markLines.push({ xAxis: p10, name: 'P10', label: { formatter: 'P10', position: 'insideEndTop' }, lineStyle: { color: '#0a8043', type: 'dashed' } });
		if (p50) markLines.push({ xAxis: p50, name: 'P50', label: { formatter: 'P50 (mediana)', position: 'insideEndTop' }, lineStyle: { color: '#1f6feb', type: 'solid', width: 2 } });
		if (p90) markLines.push({ xAxis: p90, name: 'P90', label: { formatter: 'P90', position: 'insideEndTop' }, lineStyle: { color: '#d97706', type: 'dashed' } });
		if (dataFi) markLines.push({ xAxis: dataFi, name: 'Data fi prevista', label: { formatter: 'Data fi prevista', position: 'insideEndBottom', color: '#b91c1c' }, lineStyle: { color: '#b91c1c', type: 'dotted', width: 2 } });

		return {
			tooltip: {
				trigger: 'axis',
				axisPointer: { type: 'shadow' },
				formatter: (params: any) => {
					const p = Array.isArray(params) ? params[0] : params;
					const total = y.reduce((a, b) => a + b, 0);
					const pct = total > 0 ? ((p.value / total) * 100).toFixed(1) : '0';
					return `<strong>${p.axisValueLabel}</strong><br/>${p.value} sims (${pct}%)`;
				}
			},
			grid: { left: 50, right: 30, top: 50, bottom: 80 },
			xAxis: {
				type: 'category',
				data: x,
				axisLabel: {
					rotate: 45,
					interval: Math.max(0, Math.floor(x.length / 12))
				}
			},
			yAxis: {
				type: 'value',
				name: 'Simulacions',
				nameTextStyle: { fontSize: 11 }
			},
			series: [
				{
					name: 'Simulacions',
					type: 'bar',
					data: y,
					itemStyle: { color: '#7c3aed' },
					markLine: {
						symbol: 'none',
						data: markLines
					}
				}
			]
		};
	}

	function refresh() {
		if (!chart) return;
		chart.setOption(buildOption(), true);
	}

	onMount(() => {
		chart = echarts.init(chartDom);
		refresh();
		const onResize = () => chart?.resize();
		window.addEventListener('resize', onResize);
		return () => {
			window.removeEventListener('resize', onResize);
			chart?.dispose();
			chart = null;
		};
	});

	$: if (chart && (dates || dataFi || p10 || p50 || p90)) {
		refresh();
	}
</script>

<div bind:this={chartDom} class="hsc-chart"></div>

<style>
	.hsc-chart {
		width: 100%;
		height: 360px;
		background: var(--paper-elevated);
		border: 1px solid var(--rule);
	}
</style>
