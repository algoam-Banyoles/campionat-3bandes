<!DOCTYPE html>
<html lang="ca">
	<head>
		<meta charset="utf-8" />
		<link rel="icon" href="/favicon.ico" />
		<meta name="viewport" content="width=device-width, initial-scale=1" />
		<title>Sense connexió - Campionat 3 Bandes</title>
		<style>
			body {
				font-family: system-ui, -apple-system, sans-serif;
				display: flex;
				align-items: center;
				justify-content: center;
				min-height: 100vh;
				margin: 0;
				padding: 20px;
				background: #f8fafc;
				color: #334155;
			}
			.container {
				text-align: center;
				max-width: 400px;
			}
			h1 {
				font-size: 1.5rem;
				margin-bottom: 1rem;
				color: #1e293b;
			}
			p {
				margin-bottom: 1.5rem;
				line-height: 1.6;
			}
			button {
				background: #3b82f6;
				color: white;
				border: none;
				padding: 0.75rem 1.5rem;
				border-radius: 0.375rem;
				cursor: pointer;
				font-size: 1rem;
			}
			button:hover {
				background: #2563eb;
			}
		</style>
	</head>
	<body>
		<div class="container">
			<h1>📶 Sense connexió</h1>
			<p>No hi ha connexió a internet. Comprova la teva connexió i torna-ho a intentar.</p>
			<button onclick={() => window.location.reload()}>Tornar a intentar</button>
		</div>
	</body>
</html>