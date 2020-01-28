const { getConfig } = require('../../scripts/get-config');

const parsedConfig = getConfig();

const webpack = require('webpack');
const path = require('path');
const glob = require('glob');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const TerserJSPlugin = require('terser-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const PurgecssPlugin = require('purgecss-webpack-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const { mapValues } = require('lodash');

const paths = {
	CWD: path.resolve(__dirname),
	DIST: path.resolve(__dirname, 'dist'),
	SRC: path.resolve(__dirname, 'src')
};

const srcPath = subdir => path.join(paths.SRC, subdir);

// Custom PurgeCSS extractor for Tailwind that allows special characters in class names.
class TailwindExtractor {
	static extract(content) {
		// eslint-disable-next-line no-useless-escape
		return content.match(/[A-z0-9-:\/]+/g) || [];
	}
}

let commitHash = 'none';

try {
	commitHash = require('child_process')
		.execSync('git rev-parse --short HEAD')
		.toString()
		.trim();
} catch (_err) {
	const hash = process.env.COMMIT_HASH;
	if (hash !== undefined) {
		commitHash = hash.slice(0, 8);
	}
}

module.exports = env => {
	// https://webpack.js.org/guides/environment-variables/
	const isProd = env.NODE_ENV === 'production';

	const ifProd = (val, alt) => {
		if (typeof val === 'undefined') {
			return isProd;
		}
		return isProd ? val : alt;
	};
	const ifDev = (val, alt) => {
		if (typeof val === 'undefined') {
			return !isProd;
		}
		return !isProd ? val : alt;
	};

	const envKeys = Object.keys(env).reduce((acc, cur) => {
		acc[cur] = JSON.stringify(env[cur]);
		return acc;
	}, {});

	Object.assign(envKeys, mapValues(parsedConfig, JSON.stringify));

	// If we don't already have an env specified on the command line with `--env.APP_ENV` from
	// package.json, grab it from the environment variable.
	if (!envKeys.APP_ENV) {
		envKeys.APP_ENV = JSON.stringify(process.env.APP_ENV);
	}

	envKeys.COMMIT_HASH = JSON.stringify(commitHash);

	return {
		entry: {
			main: path.join(paths.SRC, 'main.tsx')
		},
		output: {
			// With no config, clean-webpack-plugin will remove files in this dir
			path: paths.DIST,
			publicPath: parsedConfig.CLIENT_PUBLIC_PATH,
			filename: isProd ? 'js/[name].[contenthash:10].js' : 'js/[name].js'
		},
		devtool: isProd ? 'source-map' : 'inline-source-map',
		module: {
			rules: [
				{
					test: /\.tsx?$/,
					exclude: /node_modules/,
					use: [
						{
							loader: 'ts-loader',
							options: {
								projectReferences: true
							}
						}
					]
				},
				{
					test: /\.css$/,
					// Loader chaining works from right to left
					use: [
						MiniCssExtractPlugin.loader,
						{
							loader: 'css-loader',
							options: {
								importLoaders: 1,
								sourceMap: ifDev()
							}
						},
						{
							loader: 'postcss-loader',
							options: {
								sourceMap: ifDev()
							}
						}
					]
				},
				{
					test: /\.(png|jpg|woff|woff2|eot|ttf|svg)$/,
					use: [
						{
							loader: 'url-loader',
							options: {
								limit: 8192,
								fallback: 'file-loader',

								// fallback options
								outputPath: 'assets',
								name: isProd ? '[name].[hash:10].[ext]' : '[name].[ext]'
							}
						}
					]
				}
			]
		},
		resolve: {
			extensions: ['.ts', '.tsx', '.js', 'jsx'],
			// These must match the corresponding entries in tsconfig.json
			alias: {
				'@api': srcPath('api/'),
				'@components': srcPath('components/'),
				'@models': srcPath('models/'),
				'@screens': srcPath('screens/'),
				'@stores': srcPath('stores/'),
				'@themes': srcPath('themes/'),
				'@utilities': srcPath('utilities/')
			}
		},
		optimization: {
			minimizer: [new TerserJSPlugin({ sourceMap: true }), new OptimizeCSSAssetsPlugin()],
			runtimeChunk: 'single',
			splitChunks: {
				cacheGroups: {
					vendor: {
						test: /[\\/]node_modules[\\/]/,
						name: 'vendors',
						chunks: 'initial'
					}
				}
			}
		},
		plugins: [
			new MiniCssExtractPlugin({
				filename: isProd ? 'styles/[name].[contenthash:10].css' : 'styles/[name].css'
			}),
			new HtmlWebpackPlugin({
				inject: false,
				template: 'src/index.html'
			}),
			new CleanWebpackPlugin(),
			new webpack.DefinePlugin({ 'process.env': envKeys }),
			ifProd(
				new PurgecssPlugin({
					paths: glob.sync(path.join(paths.SRC, '/**/*.{ts,tsx,js,jsx,html}')),
					extractors: [
						{
							extractor: TailwindExtractor,
							extensions: ['ts', 'tsx', 'js', 'jsx', 'html']
						}
					],
					whitelist: ['active', 'blockquote', 'pre', 'code', 'table', 'th', 'tr', 'td', 'ul', 'ol'],
					// Target all classes here that are dynamically assembled somewhere in a component,
					// e.g. with `btn-${color}`
					whitelistPatterns: [
						/^btn-/,
						/\-appear$/,
						/\-appear-active$/,
						/\-appear-done$/,
						/\-enter$/,
						/\-enter-active$/,
						/\-enter-done$/,
						/\-exit$/,
						/\-exit-active$/,
						/\-exit-done$/
					]
				})
			),
			ifDev(new webpack.NamedModulesPlugin()),
			ifProd(new webpack.HashedModuleIdsPlugin()),
			ifProd(
				new webpack.BannerPlugin({
					banner: `MPS On Track Application - Copyright ${new Date().getFullYear()} Double Line, Inc. - All Rights Reserved (${commitHash})`
				})
			)
		].filter(el => !!el),

		stats: 'minimal',

		devServer: {
			port: 8001,
			hot: true,
			historyApiFallback: true,
			disableHostCheck: true
		}
	};
};
