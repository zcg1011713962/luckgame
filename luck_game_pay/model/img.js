/**
 * 头像
 */
const path = require('path');
const fs = require('fs');

class Img {

    /**
     * Function to generate random string
     * @param length
     * @returns {string}
     */
    getRandStr(length) {
        let result = '';
        const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        const charactersLength = characters.length;
        for (let i = 0; i < length; i++) {
            result += characters.charAt(Math.floor(Math.random() * charactersLength));
        }
        return result;
    }

    /**
     * Function to get public path
     * @returns {string}
     */
    getPublicPath() {
        return path.resolve(APP_ROOT);
    }

    /**
     * Function to save base64 image to file
     * @param img
     * @param fileName
     * @returns {Promise<string|number>}
     */
    async base64imgsave(img, fileName) {
        const b64img = img.substring(0, 100);
        const match = b64img.match(/^data:\s*image\/(\w+);base64,/);
        if (match) {
            const basePath = this.getPublicPath();
            const ymd = new Date().toISOString().slice(0, 10).replace(/-/g, '');
            const staticDir = 'public';
            const baseDir = `storage/${ymd}`;
            const fullPath = path.join(basePath, `${staticDir}/${baseDir}`);
            if (!fs.existsSync(fullPath)) {
                fs.mkdirSync(fullPath, {recursive: true});
            }
            const photoPath = `/${fileName}`;
            const base64Image = img.replace(match[0], '');
            const filePath = path.join(fullPath, photoPath);

            fs.writeFileSync(filePath, Buffer.from(base64Image, 'base64'));
            return `${config.img_url}/${baseDir}/${fileName}`;
        }
        return 500;
    }
}

module.exports = new Img();