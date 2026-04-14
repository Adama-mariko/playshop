import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],
	server: {
		allowedHosts: [
			'eight-books-mix.loca.lt',
			'red-cycles-share.loca.lt',
			'localhost',
			'.loca.lt'
		]
	}
});

// import { sveltekit } from '@sveltejs/kit/vite';
// import { defineConfig } from 'vite';


// export default defineConfig({
// 	plugins: [sveltekit()]
// });